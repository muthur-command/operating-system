#!/bin/bash
# Create MiniLoaderAll.bin for RK3576 update.img packaging.
set -euo pipefail

binaries_dir="${1:?binaries dir}"
host_dir="${2:?host dir}"

out="${binaries_dir}/MiniLoaderAll.bin"
pack_dir="${host_dir}/share/rockchip-pack"
rkbin="${pack_dir}/rkbin"
boot_merger="${host_dir}/bin/rockchip-boot_merger"
ini="${rkbin}/RKBOOT/RK3576MINIALL.ini"

if [ ! -x "${boot_merger}" ]; then
	echo "ERROR: missing ${boot_merger} (enable BR2_PACKAGE_HOST_ROCKCHIP_PACK)" >&2
	exit 1
fi
if [ ! -f "${ini}" ]; then
	echo "ERROR: missing ${ini}" >&2
	exit 1
fi

(
	cd "${rkbin}"
	"${boot_merger}" "${ini}"
)

loader="$(find "${rkbin}" -maxdepth 1 -name 'rk3576_spl_loader_*.bin' | head -1)"
if [ -z "${loader}" ]; then
	echo "ERROR: boot_merger did not produce rk3576_spl_loader_*.bin" >&2
	exit 1
fi

cp -f "${loader}" "${out}"
echo "Created ${out}"
