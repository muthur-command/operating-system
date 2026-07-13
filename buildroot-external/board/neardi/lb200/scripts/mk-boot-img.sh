#!/bin/bash
# Build FIT boot.img for Neardi LB200 (boot_a / boot_b), mainline U-Boot.
# Booted via `bootm` from the raw boot_a partition; load addresses are real
# RK3576 DRAM addresses (kernel_addr_r / fdt_addr_r), see boot.its.
set -euo pipefail

board_dir="${1:?board dir}"
binaries_dir="${2:?binaries dir}"
host_dir="${3:?host dir}"

kernel_img="${binaries_dir}/Image"
dtb_img="${binaries_dir}/rk3576-mc-neardi-lb200.dtb"
boot_its="${board_dir}/boot.its"
boot_fit="${binaries_dir}/boot.fit"

if [ ! -f "${kernel_img}" ]; then
	echo "ERROR: missing kernel Image at ${kernel_img}" >&2
	exit 1
fi

if [ ! -f "${dtb_img}" ]; then
	dtb_img="$(echo "${binaries_dir}"/*.dtb | awk '{print $1}')"
fi

if [ ! -f "${dtb_img}" ]; then
	echo "ERROR: missing device tree blob in ${binaries_dir}" >&2
	exit 1
fi

tmp_its="$(mktemp)"
trap 'rm -f "${tmp_its}"' EXIT

sed \
	-e "s~@KERNEL_IMG@~${kernel_img}~" \
	-e "s~@KERNEL_DTB@~${dtb_img}~" \
	"${boot_its}" > "${tmp_its}"

# Embedded FIT (data inside the image): the bootcmd reads the whole boot_a
# partition into RAM and runs `bootm`, so all sub-images must be self-contained.
"${host_dir}/bin/mkimage" -f "${tmp_its}" "${boot_fit}"
echo "Created ${boot_fit}"
