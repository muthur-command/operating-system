#!/bin/bash
# shellcheck disable=SC1090,SC1091
set -e

SCRIPT_DIR=${BR2_EXTERNAL_MCOS_PATH}/scripts
BOARD_DIR=${2}

. "${BR2_EXTERNAL_MCOS_PATH}/meta"
. "${BOARD_DIR}/meta"

. "${SCRIPT_DIR}/rootfs-layer.sh"
. "${SCRIPT_DIR}/name.sh"
. "${SCRIPT_DIR}/rauc.sh"


# MCOS rootfs post-build tasks
fix_rootfs
install_tini_docker
setup_localtime
setup_vconsole

# Write os-release
# shellcheck disable=SC2153
(
    echo "NAME=\"${MCOS_NAME}\""
    echo "VERSION=\"$(mcos_version) (${BOARD_NAME})\""
    echo "ID=${MCOS_ID}"
    echo "VERSION_ID=$(mcos_version)"
    echo "PRETTY_NAME=\"${MCOS_NAME} $(mcos_version)\""
    echo "CPE_NAME=cpe:2.3:o:muthur-command:${MCOS_ID}:$(mcos_version):*:${DEPLOYMENT}:*:*:*:${BOARD_ID}:*"
    echo "HOME_URL=https://www.muthur-command.com/"
    echo "VARIANT=\"${MCOS_NAME} ${BOARD_NAME}\""
    echo "VARIANT_ID=${BOARD_ID}"
    echo "SUPERVISOR_MACHINE=${SUPERVISOR_MACHINE}"
    echo "SUPERVISOR_ARCH=${SUPERVISOR_ARCH}"
) > "${TARGET_DIR}/usr/lib/os-release"

# Write machine-info
(
    echo "CHASSIS=${CHASSIS}"
    echo "DEPLOYMENT=${DEPLOYMENT}"
) > "${TARGET_DIR}/etc/machine-info"


# Setup RAUC / Rockchip OTA
if [ "${OTA_BACKEND:-rauc}" = "rauc" ]; then
    prepare_rauc_signing
    write_rauc_config
    install_rauc_certs
    install_bootloader_config
elif [ -f "${BOARD_DIR}/post-build.sh" ]; then
    # shellcheck disable=SC1090
    . "${BOARD_DIR}/post-build.sh"
fi

# Fix overlay presets
"${HOST_DIR}/bin/systemctl" --root="${TARGET_DIR}" preset-all

# Board masks must run after preset-all (masking before preset causes harmless
# "Failed to preset unit" noise and can confuse builders).
if [ -f "${BOARD_DIR}/post-preset.sh" ]; then
    # shellcheck disable=SC1090
    . "${BOARD_DIR}/post-preset.sh"
fi
