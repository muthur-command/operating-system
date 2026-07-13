#!/bin/bash
# Rockchip SDK-style disk image (parameter-ab) for Neardi LB200 only.
set -euo pipefail

size_to_bytes() {
	local size="${1}"
	local num unit
	num="${size%[MmGgKk]}"
	unit="${size#$num}"
	case "${unit}" in
	M|m) echo $((num * 1024 * 1024)) ;;
	G|g) echo $((num * 1024 * 1024 * 1024)) ;;
	K|k) echo $((num * 1024)) ;;
	*) echo "${num}" ;;
	esac
}

create_disk_image_board() {
	local scripts_dir
	scripts_dir="${BOARD_DIR}/scripts"

	if [ ! -x "${HOST_DIR}/bin/rockchip-afptool" ]; then
		echo "ERROR: host rockchip-pack tools missing (BR2_PACKAGE_HOST_ROCKCHIP_PACK)" >&2
		exit 1
	fi

	export GENIMAGE_INPUTPATH="${BINARIES_DIR}"
	export GENIMAGE_OUTPUTPATH="${BINARIES_DIR}"
	export GENIMAGE_TMPPATH="${BUILD_DIR}/genimage.tmp"

	export DISK_SIZE="${DISK_SIZE:-32G}"
	export SYSTEM_PART_SIZE="${SYSTEM_PART_SIZE:-7168M}"
	export BOOT_SPL_TYPE="spl"
	export IMAGE_NAME
	IMAGE_NAME="$(mcos_image_basename)"

	local disk_bytes system_bytes system_a_off system_b_off oem_off userdata_off
	disk_bytes="$(size_to_bytes "${DISK_SIZE}")"
	system_bytes="$(size_to_bytes "${SYSTEM_PART_SIZE}")"
	system_a_off=$((240 * 1024 * 1024))
	system_b_off=$((system_a_off + system_bytes))
	oem_off=$((system_b_off + system_bytes))
	userdata_off=$((oem_off + 128 * 1024 * 1024))
	# Leave room for the GPT backup header/array at the end of the disk image.
	local gpt_backup_size=$((33 * 512))
	export SYSTEM_B_OFFSET="$((system_b_off / 1024 / 1024))M"
	export OEM_OFFSET="$((oem_off / 1024 / 1024))M"
	export USERDATA_OFFSET="$((userdata_off / 1024 / 1024))M"
	export USERDATA_PART_SIZE="$((disk_bytes - userdata_off - gpt_backup_size))"

	local rootfs_image="${BINARIES_DIR}/rootfs.ext4"
	local userdata_image
	userdata_image="$(path_data_img)"

	if [ ! -f "${rootfs_image}" ]; then
		echo "ERROR: missing ${rootfs_image} (enable BR2_TARGET_ROOTFS_EXT2)" >&2
		exit 1
	fi
	if [ ! -f "${userdata_image}" ]; then
		echo "ERROR: missing ${userdata_image}" >&2
		exit 1
	fi

	if command -v "${HOST_DIR}/sbin/e2label" >/dev/null 2>&1; then
		"${HOST_DIR}/sbin/e2label" "${userdata_image}" userdata || true
	fi

	ln -sf "$(basename "${rootfs_image}")" "${BINARIES_DIR}/rootfs.img"
	ln -sf "$(basename "${userdata_image}")" "${BINARIES_DIR}/userdata.img"

	bash "${scripts_dir}/mk-boot-img.sh" "${BOARD_DIR}" "${BINARIES_DIR}" "${HOST_DIR}"
	bash "${scripts_dir}/mk-loader.sh" "${BINARIES_DIR}" "${HOST_DIR}"
	bash "${scripts_dir}/mk-uboot-img.sh" "${BINARIES_DIR}" "${HOST_DIR}" "${BUILD_DIR}"

	# Vendor SPL checks FDT_MAGIC (0xd00dfeed) at uboot LBA 0x4000 and 0x5000.
	for off in 0 $((2 * 1024 * 1024)); do
		magic="$(dd if="${BINARIES_DIR}/uboot.img" bs=1 skip="${off}" count=4 status=none \
			| hexdump -e '4/1 "%02x"')"
		if [ "${magic}" != "d00dfeed" ]; then
			echo "ERROR: uboot.img lacks FIT magic at offset ${off} (got ${magic})" >&2
			exit 1
		fi
	done

	bash "${scripts_dir}/mk-misc-img.sh" "${BINARIES_DIR}"

	# Sanity-check boot.fit load addresses before packaging (mainline RK3576 DRAM map).
	if command -v "${HOST_DIR}/bin/mkimage" >/dev/null 2>&1; then
		boot_loads="$("${HOST_DIR}/bin/mkimage" -l "${BINARIES_DIR}/boot.fit" 2>/dev/null \
			| grep 'Load Address' | awk '{print $3}' | tr '\n' ' ')"
		case "${boot_loads}" in
		*"0x42000000"*"0x52000000"*) ;;
		*)
			echo "ERROR: boot.fit load addresses (${boot_loads}) are not mainline RK3576 (expect 0x42000000 0x52000000)" >&2
			exit 1
			;;
		esac
	fi

	trap 'rm -rf "${ROOTPATH_TMP}" "${GENIMAGE_TMPPATH}"' EXIT
	ROOTPATH_TMP="$(mktemp -d)"
	rm -rf "${GENIMAGE_TMPPATH}"

	genimage \
		--rootpath "${ROOTPATH_TMP}" \
		--configdump - \
		--includepath "${BOARD_DIR}:${BR2_EXTERNAL_MCOS_PATH}/genimage"

	# Rockchip update.img expects these filenames
	cp -f "${BINARIES_DIR}/boot.fit" "${BINARIES_DIR}/boot.img"

	bash "${scripts_dir}/mk-updateimg.sh" \
		"${BOARD_DIR}" \
		"${BINARIES_DIR}" \
		"${HOST_DIR}" \
		"$(basename "${IMAGE_NAME}")"

	manifest="${BINARIES_DIR}/FLASH_LB200.txt"
	uboot_fit_md5="$(dd if="${BINARIES_DIR}/uboot.img" bs=1 count=$((2 * 1024 * 1024)) 2>/dev/null | md5sum | awk '{print $1}')"
	cat > "${manifest}" <<EOF
# LB200 flash manifest ($(date -u +%Y-%m-%dT%H:%M:%SZ))
#
# RKDevTool (MaskRom / Loader mode):
#   1. Select "Upgrade Firmware" (升级固件), NOT "Download Image" only.
#   2. Load the *uncompressed* file below (never *.xz, never *-ab-ota).
#   3. After flash, serial must show "U-Boot 2026.04" (not only 2017.09 SPL).
#
# If SPL still prints "Not fit magic" at 0x4000/0x5000, uboot was not written:
#   rkdeveloptool db MiniLoaderAll.bin
#   rkdeveloptool wl 0x4000 uboot.img
#
boot.img.md5=$(md5sum "${BINARIES_DIR}/boot.img" | awk '{print $1}')
boot.fit.kernel_load=0x42000000
boot.fit.fdt_load=0x52000000
uboot.img.md5=$(md5sum "${BINARIES_DIR}/uboot.img" | awk '{print $1}')
uboot.img.size=$(stat -c %s "${BINARIES_DIR}/uboot.img")
uboot.fit_slot0.md5=${uboot_fit_md5}
MiniLoaderAll.md5=$(md5sum "${BINARIES_DIR}/MiniLoaderAll.bin" | awk '{print $1}')
update_ab=${BINARIES_DIR}/$(basename "${IMAGE_NAME}").ab
update_ab.md5=$(md5sum "${BINARIES_DIR}/$(basename "${IMAGE_NAME}").ab" | awk '{print $1}')
EOF
	echo "Wrote ${manifest}"
	cat "${manifest}"
}
