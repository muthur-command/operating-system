################################################################################
# Copy canonical SKW driver sources into the kernel tree after patches apply.
# Patch 0003-skwifi-driver drops files under misc/ and net/wireless/ (wrong
# paths); the maintained tree lives under kernel/v6.18.y/drivers/.
# All Kbuild hooks (Kconfig + Makefile) are applied here instead of patch 0039
# because GNU patch 2.7 rejects multi-file / EOF hunks on this tree.
################################################################################

define LINUX_INSTALL_SKWIFI_DRIVERS
	rm -rf $(LINUX_DIR)/drivers/misc/seekwaveplatform_v20
	rm -rf $(LINUX_DIR)/drivers/net/wireless/rockchip_wlan
	cp -a $(BR2_EXTERNAL_MCOS_PATH)/kernel/v6.18.y/drivers/misc/seekwaveplatform_v20 \
		$(LINUX_DIR)/drivers/misc/
	cp -a $(BR2_EXTERNAL_MCOS_PATH)/kernel/v6.18.y/drivers/net/wireless/rockchip_wlan \
		$(LINUX_DIR)/drivers/net/wireless/
	mkdir -p $(LINUX_DIR)/include/linux/platform_data
	cp -a $(BR2_EXTERNAL_MCOS_PATH)/kernel/v6.18.y/include/linux/platform_data/skw_platform_data.h \
		$(LINUX_DIR)/include/linux/platform_data/
	grep -q 'seekwaveplatform_v20/Kconfig' $(LINUX_DIR)/drivers/misc/Kconfig || \
		sed -i '/source "drivers\/misc\/rp1\/Kconfig"/a source "drivers/misc/seekwaveplatform_v20/Kconfig"' \
			$(LINUX_DIR)/drivers/misc/Kconfig
	grep -q 'rockchip_wlan/skwifi/Kconfig' $(LINUX_DIR)/drivers/net/wireless/Kconfig || \
		sed -i '/source "drivers\/net\/wireless\/virtual\/Kconfig"/a source "drivers/net/wireless/rockchip_wlan/skwifi/Kconfig"' \
			$(LINUX_DIR)/drivers/net/wireless/Kconfig
	grep -q 'seekwaveplatform_v20/' $(LINUX_DIR)/drivers/misc/Makefile || \
		echo 'obj-$$(CONFIG_SEEKWAVE_BSP_DRIVERS_V20) += seekwaveplatform_v20/' \
			>> $(LINUX_DIR)/drivers/misc/Makefile
	grep -q 'rockchip_wlan/skwifi/' $(LINUX_DIR)/drivers/net/wireless/Makefile || \
		echo 'obj-$$(CONFIG_WLAN_VENDOR_SKW6316) += rockchip_wlan/skwifi/' \
			>> $(LINUX_DIR)/drivers/net/wireless/Makefile
endef
LINUX_POST_PATCH_HOOKS += LINUX_INSTALL_SKWIFI_DRIVERS
