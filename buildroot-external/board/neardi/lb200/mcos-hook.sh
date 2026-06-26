#!/bin/bash
# shellcheck disable=SC2155
# Neardi LB200 板级 hook 脚本

function mcos_pre_image() {
    local BOOT_DATA="$(path_boot_dir)"

    # 复制 boot 脚本和设备树
    cp "${BINARIES_DIR}/boot.scr" "${BOOT_DATA}/boot.scr"
    cp "${BINARIES_DIR}"/*.dtb "${BOOT_DATA}/"

    # 复制启动配置文件
    cp "${BOARD_DIR}/boot-env.txt" "${BOOT_DATA}/mcos-config.txt"
    cp "${BOARD_DIR}/cmdline.txt" "${BOOT_DATA}/cmdline.txt"

    # 复制 WiFi 固件到 boot 分区（如果存在）
    if [ -d "${BINARIES_DIR}/lib/firmware/seekwave" ]; then
        mkdir -p "${BOOT_DATA}/firmware"
        cp -r "${BINARIES_DIR}/lib/firmware/seekwave" "${BOOT_DATA}/firmware/"
    fi
}

function mcos_post_image() {
    convert_disk_image_xz
}
