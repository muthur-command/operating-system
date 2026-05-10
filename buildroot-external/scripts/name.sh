#!/bin/bash

function mcos_image_name() {
    echo "${BINARIES_DIR}/${MCOS_ID}_${BOARD_ID}-$(mcos_version).${1}"
}

function mcos_image_basename() {
    echo "${BINARIES_DIR}/${MCOS_ID}_${BOARD_ID}-$(mcos_version)"
}

function mcos_rauc_compatible() {
    echo "${MCOS_ID}-${BOARD_ID}"
}

function mcos_version() {
    if [ -z "${VERSION_SUFFIX}" ]; then
        echo "${VERSION_MAJOR}.${VERSION_MINOR}"
    else
        echo "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_SUFFIX}"
    fi
}

function path_boot_dir() {
    echo "${BINARIES_DIR}/boot"
}

function path_data_img() {
    echo "${BINARIES_DIR}/data.ext4"
}

function path_rootfs_img() {
    echo "${BINARIES_DIR}/rootfs.erofs"
}
