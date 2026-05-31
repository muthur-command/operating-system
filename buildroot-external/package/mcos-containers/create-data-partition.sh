#!/usr/bin/env bash
set -e

build_dir=$1
dst_dir=$2
channel=$3
docker_version=$4

data_img="${dst_dir}/data.ext4"
data_dir="${build_dir}/data"
container=""
dind_image="${MCOS_CONTAINERS_DIND_IMAGE:-docker:${docker_version}-dind}"
# Default data partition size. Override via MCOS_CONTAINERS_DATA_PART_SIZE (e.g. 8192M).
# Must be large enough to hold all imported container images plus the
# overlayfs snapshots used by containerd-snapshotter (uncompressed).
data_part_size="${MCOS_CONTAINERS_DATA_PART_SIZE:-8192M}"
# Set to "1" to shrink data.ext4 to minimum size after import. The runtime
# mcos-expand service grows it back to the physical disk on first boot, so the
# distributed image stays small.
data_part_shrink="${MCOS_CONTAINERS_DATA_PART_SHRINK:-1}"

APPARMOR_URL="https://version.muthur-command.com/apparmor_${channel}.txt"

cleanup() {
	if [[ -n "${container}" ]]; then
		docker rm -f "${container}" > /dev/null 2>&1 || true
	fi
	sudo umount "${data_dir}" > /dev/null 2>&1 || true
}
trap cleanup ERR EXIT

wait_for_docker() {
	local retries=30
	until docker info > /dev/null 2>&1; do
		if (( retries <= 0 )); then
			echo "::error::Docker daemon is not ready" >&2
			return 1
		fi
		sleep 1
		retries=$((retries - 1))
	done
}

pull_dind_image() {
	local retries=5
	local delay=5

	wait_for_docker

	while (( retries > 0 )); do
		if docker pull "${dind_image}"; then
			return 0
		fi
		echo "Retrying docker pull ${dind_image} in ${delay}s (${retries} retries left)..." >&2
		sleep "${delay}"
		delay=$((delay * 2))
		retries=$((retries - 1))
	done

	echo "::error::Failed to pull ${dind_image}. Set MCOS_CONTAINERS_DIND_IMAGE to a reachable mirror or pre-pull the image." >&2
	return 1
}

# Pull dind before mounting so a failed pull does not leave a root-owned
# ext4 mount (lost+found) that blocks mcos-containers-dirclean.
pull_dind_image

# Make image
rm -f "${data_img}"
truncate --size="${data_part_size}" "${data_img}"
mkfs.ext4 -L "mcos-data" -E lazy_itable_init=0,lazy_journal_init=0 "${data_img}"

# Mount / init file structs
mkdir -p "${data_dir}"
sudo mount -o loop,discard "${data_img}" "${data_dir}"

# Use official Docker in Docker images
# We use the same version as Buildroot is using to ensure best compatibility
container=$(docker run --privileged -e DOCKER_TLS_CERTDIR="" \
	-v "${data_dir}":/mnt/data \
	-v "${build_dir}":/build \
	-d "${dind_image}" --feature containerd-snapshotter --data-root /mnt/data/docker)

docker exec "${container}" sh /build/dind-import-containers.sh

sudo bash -ex <<EOF
# Indicator for docker-prepare.service to use the containerd snapshotter
touch "${data_dir}/.docker-use-containerd-snapshotter"

# Setup AppArmor
mkdir -p "${data_dir}/supervisor/apparmor"
curl -fsL -o "${data_dir}/supervisor/apparmor/mcos-supervisor" "${APPARMOR_URL}"

# Persist build-time updater channel
jq -n --arg channel "${channel}" '{"channel": \$channel}' > "${data_dir}/supervisor/updater.json"
EOF

# Stop dind so the filesystem can be safely unmounted/shrunk.
if [[ -n "${container}" ]]; then
	docker rm -f "${container}" > /dev/null 2>&1 || true
	container=""
fi

sudo umount "${data_dir}"

if [ "${data_part_shrink}" = "1" ]; then
	# Shrink data.ext4 to minimum so the distributable image is small.
	# mcos-expand will grow it back to the physical disk on first boot.
	sudo e2fsck -fy "${data_img}" || true
	sudo resize2fs -M "${data_img}"
	shrunk_blocks=$(sudo tune2fs -l "${data_img}" | awk -F': *' '/Block count/{print $2}')
	block_size=$(sudo tune2fs -l "${data_img}" | awk -F': *' '/Block size/{print $2}')
	shrunk_bytes=$(( shrunk_blocks * block_size ))
	echo "data.ext4 shrunk to $(( shrunk_bytes / 1024 / 1024 )) MiB"
	# Truncate the sparse trailing zeros from the image file.
	truncate --size="${shrunk_bytes}" "${data_img}"
fi
