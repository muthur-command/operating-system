################################################################################
#
# Rockchip firmware pack tools (host)
#
################################################################################

HOST_ROCKCHIP_PACK_VERSION = 40277c633b840a0c44756c9f3a416f1696c6e01b
HOST_ROCKCHIP_PACK_SITE = $(call github,muthur-command,operating-system-blobs,$(HOST_ROCKCHIP_PACK_VERSION))
HOST_ROCKCHIP_PACK_LICENSE = ROCKCHIP
HOST_ROCKCHIP_PACK_LICENSE_FILES = $(BR2_EXTERNAL_MCOS_PATH)/package/rockchip-recovery/NOTICE

HOST_ROCKCHIP_PACK_BLOBS_DIR = $(@D)/rockchip/rk3576

define HOST_ROCKCHIP_PACK_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_BLOBS_DIR)/tools/linux-x86_64/afptool \
		$(HOST_DIR)/bin/rockchip-afptool
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_BLOBS_DIR)/tools/linux-x86_64/rkImageMaker \
		$(HOST_DIR)/bin/rockchip-rkImageMaker
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_BLOBS_DIR)/tools/linux-x86_64/boot_merger \
		$(HOST_DIR)/bin/rockchip-boot_merger
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_BLOBS_DIR)/tools/linux-x86_64/loaderimage \
		$(HOST_DIR)/bin/rockchip-loaderimage
	$(INSTALL) -d -m 0755 $(HOST_DIR)/share/rockchip-pack
	cp -a $(HOST_ROCKCHIP_PACK_BLOBS_DIR)/rkbin \
		$(HOST_DIR)/share/rockchip-pack/
endef

$(eval $(host-generic-package))
