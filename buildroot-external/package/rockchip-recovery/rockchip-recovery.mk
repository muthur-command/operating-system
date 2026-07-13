################################################################################
#
# Rockchip updateEngine (vendored recovery sources)
#
################################################################################

ROCKCHIP_RECOVERY_VERSION = 1.0
ROCKCHIP_RECOVERY_SITE = $(BR2_EXTERNAL_MCOS_PATH)/package/rockchip-recovery/src
ROCKCHIP_RECOVERY_SITE_METHOD = local

ROCKCHIP_RECOVERY_LICENSE = ROCKCHIP
ROCKCHIP_RECOVERY_LICENSE_FILES = NOTICE

ROCKCHIP_RECOVERY_CFLAGS = $(TARGET_CFLAGS) -I. \
	-fPIC \
	-lpthread \
	-lcurl \
	-lbz2

ROCKCHIP_RECOVERY_MAKE_ENV = $(TARGET_MAKE_ENV) RecoveryNoUi=true
ROCKCHIP_RECOVERY_CFLAGS += -DUSE_UPDATEENGINE=ON

ROCKCHIP_RECOVERY_DEPENDENCIES += libpthread-stubs util-linux libcurl bzip2 openssl

ifeq ($(BR2_PACKAGE_ROCKCHIP_RECOVERY_SUCCESSFUL_BOOT),y)
ROCKCHIP_RECOVERY_CFLAGS += -DSUCCESSFUL_BOOT=ON
endif

define ROCKCHIP_RECOVERY_BUILD_CMDS
	$(ROCKCHIP_RECOVERY_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" CFLAGS="$(ROCKCHIP_RECOVERY_CFLAGS)"
endef

ifeq ($(BR2_PACKAGE_ROCKCHIP_RECOVERY_UPDATEENGINE),y)
define ROCKCHIP_RECOVERY_INSTALL_UPDATEENGINE
	$(INSTALL) -D -m 755 $(@D)/updateEngine $(TARGET_DIR)/usr/bin/updateEngine
endef
endif

define ROCKCHIP_RECOVERY_INSTALL_TARGET_CMDS
	$(ROCKCHIP_RECOVERY_INSTALL_UPDATEENGINE)
endef

$(eval $(generic-package))
