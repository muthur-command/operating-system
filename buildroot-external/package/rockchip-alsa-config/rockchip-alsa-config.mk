################################################################################
#
# rockchip-alsa-config
#
################################################################################

ROCKCHIP_ALSA_CONFIG_VERSION = main
ROCKCHIP_ALSA_CONFIG_SITE = https://github.com/mcos-platform/alsa-config.git
ROCKCHIP_ALSA_CONFIG_SITE_METHOD = git

ROCKCHIP_ALSA_CONFIG_LICENSE = Apache-2.0

ifeq ($(BR2_ROCKCHIP_ALSA_CONFIG_INSTALL_INIT_SCRIPT),y)
define ROCKCHIP_ALSA_CONFIG_INSTALL_INIT_SCRIPT
	$(INSTALL) -D -m 0755 $(@D)/alsa-config.sh \
		$(TARGET_DIR)/etc/init.d/alsa-config
endef
ROCKCHIP_ALSA_CONFIG_POST_INSTALL_TARGET_HOOKS += ROCKCHIP_ALSA_CONFIG_INSTALL_INIT_SCRIPT
endif

define ROCKCHIP_ALSA_CONFIG_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/share/alsa/cards
	$(INSTALL) -D -m 0644 $(@D)/asound.conf \
		$(TARGET_DIR)/etc/asound.conf
endef

$(eval $(generic-package))
