#!/bin/bash
# shellcheck disable=SC2155
# Neardi LB200 — Rockchip SDK partition layout (parameter-ab) + update.img

# shellcheck disable=SC1091
. "${BOARD_DIR}/scripts/rockchip-image.sh"

function mcos_pre_image() {
	: "FIT boot.img is built in create_disk_image_board"
}

function mcos_post_image() {
	local ab_img ota_img disk_img
	ab_img="$(mcos_image_name ab)"
	ota_img="$(mcos_image_name ab-ota)"
	disk_img="$(mcos_image_name img)"

	# RKDevTool needs an uncompressed update.img.  xz(1) deletes the source file
	# by default; replace any leftover symlinks with real file copies.
	rm -f "${BINARIES_DIR}/update.img" "${BINARIES_DIR}/update-ota.img"
	cp -f "${ab_img}" "${BINARIES_DIR}/update.img"
	cp -f "${ota_img}" "${BINARIES_DIR}/update-ota.img"

	convert_disk_image_xz img
	rm -f "${ab_img}.xz" "${ota_img}.xz"
	xz -k "${MCOS_XZ_LEVEL:--6}" -T0 "${ab_img}"
	xz -k "${MCOS_XZ_LEVEL:--6}" -T0 "${ota_img}"

	echo "LB200 flash images (use uncompressed update.img with RKDevTool):"
	ls -lh "${BINARIES_DIR}/update.img" "${ab_img}" "${disk_img}" "${ab_img}.xz" 2>/dev/null || true
}
