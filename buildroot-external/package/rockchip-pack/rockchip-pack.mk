################################################################################
#
# Rockchip firmware pack tools (host)
#
################################################################################

HOST_ROCKCHIP_PACK_VERSION = 1.0
HOST_ROCKCHIP_PACK_SITE = $(BR2_EXTERNAL_MCOS_PATH)/package/rockchip-pack
HOST_ROCKCHIP_PACK_SITE_METHOD = local
HOST_ROCKCHIP_PACK_LICENSE = ROCKCHIP
HOST_ROCKCHIP_PACK_LICENSE_FILES = $(BR2_EXTERNAL_MCOS_PATH)/package/rockchip-recovery/NOTICE

define HOST_ROCKCHIP_PACK_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_PKGDIR)/bin/afptool \
		$(HOST_DIR)/bin/rockchip-afptool
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_PKGDIR)/bin/rkImageMaker \
		$(HOST_DIR)/bin/rockchip-rkImageMaker
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_PKGDIR)/bin/boot_merger \
		$(HOST_DIR)/bin/rockchip-boot_merger
	$(INSTALL) -D -m 0755 $(HOST_ROCKCHIP_PACK_PKGDIR)/bin/loaderimage \
		$(HOST_DIR)/bin/rockchip-loaderimage
	$(INSTALL) -d -m 0755 $(HOST_DIR)/share/rockchip-pack
	cp -a $(HOST_ROCKCHIP_PACK_PKGDIR)/rkbin $(HOST_DIR)/share/rockchip-pack/
endef

$(eval $(host-generic-package))
