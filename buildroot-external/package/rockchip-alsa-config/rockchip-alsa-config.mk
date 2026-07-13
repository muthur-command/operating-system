################################################################################
#
# rockchip-alsa-config
#
################################################################################

ROCKCHIP_ALSA_CONFIG_VERSION = main
ROCKCHIP_ALSA_CONFIG_SITE = https://github.com/mcos-platform/alsa-config.git
ROCKCHIP_ALSA_CONFIG_SITE_METHOD = git

ROCKCHIP_ALSA_CONFIG_LICENSE = Apache-2.0
ROCKCHIP_ALSA_CONFIG_LICENSE_FILES = NOTICE

ifeq ($(BR2_ROCKCHIP_ALSA_CONFIG_INSTALL_INIT_SCRIPT),y)
ROCKCHIP_ALSA_CONFIG_CONF_OPTS += -Dinit_script=enabled
endif

$(eval $(meson-package))
