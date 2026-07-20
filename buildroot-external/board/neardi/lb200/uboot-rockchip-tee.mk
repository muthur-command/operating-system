# Pass the vendor BL32 image installed by rockchip-blobs to U-Boot's
# Rockchip FIT image generator. external.mk is included after uboot.mk, so
# these additions extend the U-Boot package without modifying Buildroot.
ifneq ($(BR2_PACKAGE_ROCKCHIP_BLOBS_TEE),)
UBOOT_MAKE_OPTS += TEE=$(BINARIES_DIR)/tee.bin

define MCOS_UBOOT_COPY_TEE_FIRMWARE
	cp $(BINARIES_DIR)/tee.bin $(@D)/
endef

UBOOT_PRE_BUILD_HOOKS += MCOS_UBOOT_COPY_TEE_FIRMWARE
endif
