#!/bin/bash
# Pack mainline u-boot.itb into Rockchip uboot.img for the 4 MiB uboot partition.
#
# RK3576 MiniLoaderAll SPL (vendor rkbin) loads U-Boot from the uboot GPT
# partition using spl_load_simple_fit().  With the default Kconfig
# (SPL_FIT_IMAGE_KB=2048, SPL_FIT_IMAGE_MULTIPLE=2) it scans absolute LBAs
# 0x4000 (partition start) and 0x5000 (+2 MiB).
#
# Vendor U-Boot's fit_gen_uboot_img() mirrors the same FIT into both 2 MiB
# slots (see rockchip_sdk/u-boot/scripts/fit-core.sh).  Match that layout so
# SPL finds mainline u-boot.itb on the first scan.
set -euo pipefail

binaries_dir="${1:?binaries dir}"
host_dir="${2:?host dir}"
build_dir="${3:?build dir}"

out="${binaries_dir}/uboot.img"
uboot_itb="$(echo "${build_dir}"/uboot-*/u-boot.itb)"
# RK3576 vendor SPL defaults (arch/arm/mach-rockchip Kconfig).
itb_slot_kb=2048
itb_slot_count=2
part_size=$((itb_slot_kb * itb_slot_count * 1024))
itb_max_bytes=$((itb_slot_kb * 1024))

if [ ! -f "${uboot_itb}" ]; then
	echo "ERROR: missing ${uboot_itb} (rebuild U-Boot first)" >&2
	exit 1
fi

if ! dtc -I dtb -O dts "${uboot_itb}" 2>/dev/null | grep -q 'os = "op-tee"'; then
	echo "ERROR: ${uboot_itb} has no optee (BL32) image; set BR2_PACKAGE_ROCKCHIP_BLOBS_TEE and rebuild U-Boot" >&2
	exit 1
fi

itb_size="$(stat -c %s "${uboot_itb}")"
if [ "${itb_size}" -gt "${itb_max_bytes}" ]; then
	echo "ERROR: u-boot.itb (${itb_size} bytes) exceeds ${itb_slot_kb} KiB SPL slot" >&2
	exit 1
fi

rm -f "${out}"
for ((i = 0; i < itb_slot_count; i++)); do
	cat "${uboot_itb}" >> "${out}"
	truncate -s "%${itb_slot_kb}K" "${out}"
done

echo "Created ${out} (${itb_slot_count}x u-boot.itb in ${itb_slot_kb} KiB slots, size ${itb_size})"
