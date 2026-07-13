#!/bin/bash
# Pack Rockchip update.img / update-ab-ota.img for Neardi LB200.
# Layout matches device/rockchip/common/scripts/mk-updateimg.sh (SDK).
set -euo pipefail

board_dir="${1:?board dir}"
binaries_dir="${2:?binaries dir}"
host_dir="${3:?host dir}"
image_basename="${4:?image basename}"

afptool="${host_dir}/bin/rockchip-afptool"
rkimagemaker="${host_dir}/bin/rockchip-rkImageMaker"

if [ ! -x "${afptool}" ] || [ ! -x "${rkimagemaker}" ]; then
	echo "ERROR: missing Rockchip pack tools (enable BR2_PACKAGE_HOST_ROCKCHIP_PACK)" >&2
	exit 1
fi

pack_updateimg() {
	local type="${1:?type}"
	local pkg_file="${2:?package file}"
	local out_img="${binaries_dir}/${image_basename}.${type}"
	local work="${binaries_dir}/update-${type}.work"
	local image_dir="${work}/Image"
	local tag

	rm -rf "${work}"
	mkdir -p "${image_dir}"

	ln -sf "${board_dir}/parameter-ab.txt" "${image_dir}/parameter.txt"
	ln -sf "${binaries_dir}/MiniLoaderAll.bin" "${image_dir}/MiniLoaderAll.bin"
	ln -sf "${binaries_dir}/uboot.img" "${image_dir}/uboot.img"
	ln -sf "${binaries_dir}/misc.img" "${image_dir}/misc.img"
	ln -sf "${binaries_dir}/boot.img" "${image_dir}/boot.img"
	ln -sf "${binaries_dir}/rootfs.img" "${image_dir}/rootfs.img"
	ln -sf "${binaries_dir}/oem.img" "${image_dir}/oem.img"
	ln -sf "${binaries_dir}/userdata.img" "${image_dir}/userdata.img"
	cp -f "${board_dir}/${pkg_file}" "${work}/package-file"
	ln -sf "../package-file" "${image_dir}/package-file"

	if [ ! -r "${image_dir}/MiniLoaderAll.bin" ]; then
		echo "ERROR: MiniLoaderAll.bin missing" >&2
		exit 1
	fi

	(
		cd "${image_dir}"
		"${afptool}" -pack ./ update.raw.img
		tag="RK$(hexdump -s 21 -n 4 -e '4 "%c"' MiniLoaderAll.bin | rev)"
		"${rkimagemaker}" -"${tag}" MiniLoaderAll.bin update.raw.img update.img \
			-os_type:androidos
	)

	cp -f "${image_dir}/update.img" "${out_img}"
	echo "Created ${out_img}"
}

pack_updateimg "ab" "package-file-ab"
pack_updateimg "ab-ota" "ota-package-file-ab"
