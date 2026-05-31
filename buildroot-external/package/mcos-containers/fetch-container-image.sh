#!/usr/bin/env bash

set -e
set -u
set -o pipefail

arch=$1
machine=$2
version_json=$3
image_json_name=$4
dl_dir=$5
dst_dir=$6

retry() {
	local retries="${1:-5}"
	local cmd=$2
	local delay=5

	local output
	local rc
	output=$(eval "$cmd") && rc=$? || rc=$?

	while [ "$rc" -ne 0 ] && [ "$retries" -gt 0 ]; do
		echo "Retrying \"$cmd\" in ${delay}s ($retries retries left)..." >&2
		sleep "${delay}s"
		# shellcheck disable=SC2004
		delay=$(($delay * 3))
		# shellcheck disable=SC2004
		retries=$(($retries - 1))
		output=$(eval "$cmd") && rc=$? || rc=$?
	done

	echo "$output"
	return $rc
}

image_name=$(jq -e -r --arg image_json_name "${image_json_name}" \
	--arg arch "${arch}" --arg machine "${machine}" \
	'.images[$image_json_name] | sub("{arch}"; $arch) | sub("{machine}"; $machine)' \
	< "${version_json}")
image_tag=$(jq -e -r --arg image_json_name "${image_json_name}" \
	'.[$image_json_name]' < "${version_json}")
full_image_name="${image_name}:${image_tag}"

# Map MCOS arch to OCI platform arch for skopeo
case "${arch}" in
	aarch64) oci_arch="arm64" ;;
	*) oci_arch="${arch}" ;;
esac

image_file_prefix="${full_image_name//[:\/]/_}@"
find_cached_image() {
	local match
	shopt -s nullglob
	local -a matches=( "${dl_dir}/${image_file_prefix}"*.tar )
	shopt -u nullglob

	if [ "${#matches[@]}" -eq 0 ]; then
		return 1
	fi

	if [ "${#matches[@]}" -gt 1 ]; then
		echo "Warning: multiple cached images for ${full_image_name}, using ${matches[0]}" >&2
	fi

	match="${matches[0]}"
	image_file_path="${match}"
	image_digest="${match##*/}"
	image_digest="${image_digest%.tar}"
	image_digest="${image_digest#*@}"
	image_digest="${image_digest/_/:}"
	return 0
}

if ! find_cached_image; then
	image_digest=$(retry 5 "skopeo inspect --override-arch '${oci_arch}' 'docker://${full_image_name}' | jq -r '.Digest'")
	# Cleanup image name file name use
	image_file_name="${full_image_name//[:\/]/_}@${image_digest//[:\/]/_}"
	image_file_path="${dl_dir}/${image_file_name}.tar"
fi

dst_image_file_path="${dst_dir}/$(basename "${image_file_path}")"

(
	# Use file locking to avoid race condition
	flock --verbose 3
	if [ ! -f "${image_file_path}" ]
	then
		echo "Fetching image: ${full_image_name} (digest ${image_digest})"
		retry 5 "skopeo copy --override-arch '${oci_arch}' 'docker://${image_name}@${image_digest}' 'oci-archive:${image_file_path}:${full_image_name}'"
	else
		echo "Skipping download of existing image: ${full_image_name} (digest ${image_digest})"
	fi

	cp "${image_file_path}" "${dst_image_file_path}"
) 3>"${image_file_path}.lock"
