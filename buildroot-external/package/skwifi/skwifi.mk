################################################################################
#
# skwifi - Seekwave WiFi/BT driver for Rockchip platforms
#
# Driver is built via kernel patches; this package installs firmware and
# boot-time module loading.
#
################################################################################

SKWIFI_VERSION = 1.0
SKWIFI_SITE = $(BR2_EXTERNAL_MCOS_PATH)/package/skwifi
SKWIFI_SITE_METHOD = local
SKWIFI_LICENSE = Proprietary

define SKWIFI_BUILD_CMDS
	@echo "SKWIFI: driver built via kernel patches"
endef

define SKWIFI_INSTALL_TARGET_CMDS
	$(if $(BR2_PACKAGE_SKWIFI_FIRMWARE),\
		mkdir -p $(TARGET_DIR)/lib/firmware && \
		if ls $(SKWIFI_PKGDIR)/fw/*.bin >/dev/null 2>&1; then \
			install -m 644 $(SKWIFI_PKGDIR)/fw/*.bin \
				$(TARGET_DIR)/lib/firmware/; \
			cd $(TARGET_DIR)/lib/firmware && \
			ln -sf ROM_EXEC_KERNEL_IRAM.bin SWT6652_IRAM_SDIO.bin && \
			ln -sf RAM_RW_KERNEL_DRAM.bin SWT6652_DRAM_SDIO.bin; \
		else \
			echo "SKWIFI WARNING: no firmware in package/skwifi/fw/"; \
			echo "SKWIFI: see package/skwifi/fw/README"; \
		fi && \
		if [ -d "$(SKWIFI_PKGDIR)/nv" ] && ls $(SKWIFI_PKGDIR)/nv/* >/dev/null 2>&1; then \
			install -m 644 $(SKWIFI_PKGDIR)/nv/* \
				$(TARGET_DIR)/lib/firmware/; \
		fi \
	)
endef

define SKWIFI_INSTALL_INIT_SYSTEMD
	mkdir -p $(TARGET_DIR)/lib/udev/rules.d
	echo 'SUBSYSTEM=="mmc", DRIVER=="sdio", ATTR{power_control}="on"' \
		> $(TARGET_DIR)/lib/udev/rules.d/85-skwifi.rules

	$(INSTALL) -D -m 0644 $(SKWIFI_PKGDIR)/skwifi.service \
		$(TARGET_DIR)/etc/systemd/system/skwifi.service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /etc/systemd/system/skwifi.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/skwifi.service
endef

$(eval $(generic-package))
