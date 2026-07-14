################################################################################
#
# rockchip-rga
#
################################################################################

ROCKCHIP_RGA_VERSION = main
ROCKCHIP_RGA_SITE = https://github.com/mcos-platform/linux-rga.git
ROCKCHIP_RGA_SITE_METHOD = git
ROCKCHIP_RGA_LICENSE = Apache-2.0
ROCKCHIP_RGA_LICENSE_FILES = COPYING

ROCKCHIP_RGA_INSTALL_STAGING = YES

ROCKCHIP_RGA_DEPENDENCIES = libdrm

ROCKCHIP_RGA_CONF_OPTS = -Dlibdrm=true

# Avoid conflict with GCC's fixincl
define ROCKCHIP_RGA_FIX_INCLUDE
	sed -i 's/ linux / __linux__ /' $(@D)/include/RgaApi.h || true
endef
ROCKCHIP_RGA_POST_RSYNC_HOOKS += ROCKCHIP_RGA_FIX_INCLUDE

$(eval $(meson-package))
