################################################################################
#
# skwifi - Seekwave WiFi/BT driver for Rockchip platforms
#
# This package provides the SKW (Seekwave) WiFi and Bluetooth
# driver for SV6160/SWT6652 modules commonly used on Rockchip
# based boards.
#
# The driver is built as a kernel module and requires the kernel
# sources with cfg80211 and mac80211 support.
#
################################################################################

SKWIFI_SITE = "$(BR2_EXTERNAL_MCOS_PATH)/package/skwifi"
SKWIFI_SITE_METHOD = local

SKWIFI_VERSION = 1.0
SKWIFI_LICENSE = Proprietary
SKWIFI_LICENSE_FILES = LICENSE

# Driver is built as kernel module
SKWIFI_MODULE = y

# The SKW driver consists of multiple components:
# - skw_cfg80211.ko: cfg80211 interface driver
# - skw_sdio.ko: SDIO interface driver
# - skw_usb.ko: USB interface driver (optional)
# - skwutil.ko: Utility functions

define SKWIFI_BUILD_CMDS
	# SKW driver is built via kernel build system
	# This package primarily installs firmware files
	# The actual driver is built as a kernel module via patches
	@echo "SKWIFI: Driver built via kernel patches"
	@echo "SKWIFI: Installing firmware files..."
endef

define SKWIFI_INSTALL_TARGET_CMDS
	# Create firmware directory
	mkdir -p $(TARGET_DIR)/lib/firmware/seekwave
	# Install WiFi firmware (if available)
	if [ -f "$(SKWIFI_SITE)/fw/SKW_WIFI_BOOT.bin" ]; then \
		install -m 644 $(SKWIFI_SITE)/fw/SKW_WIFI_BOOT.bin \
			$(TARGET_DIR)/lib/firmware/seekwave/; \
		install -m 644 $(SKWIFI_SITE)/fw/SKW_WIFI_MISSION.bin \
			$(TARGET_DIR)/lib/firmware/seekwave/; \
		install -m 644 $(SKWIFI_SITE)/fw/SKW_WIFI_FUS.bin \
			$(TARGET_DIR)/lib/firmware/seekwave/; \
	else \
		echo "SKWIFI WARNING: WiFi firmware files not found"; \
		echo "SKWIFI: Copy firmware files to package/skwifi/fw/"; \
	fi
	# Install BT firmware (if available)
	if [ -f "$(SKWIFI_SITE)/fw/SKW_BT.bin" ]; then \
		install -m 644 $(SKWIFI_SITE)/fw/SKW_BT.bin \
			$(TARGET_DIR)/lib/firmware/seekwave/; \
	else \
		echo "SKWIFI WARNING: BT firmware file not found"; \
	fi
	# Install NV files
	if [ -d "$(SKWIFI_SITE)/nv" ]; then \
		install -m 644 $(SKWIFI_SITE)/nv/* \
			$(TARGET_DIR)/lib/firmware/seekwave/; \
	fi
endef

define SKWIFI_INSTALL_INIT_SYSTEMD
	# Create udev rules for SKW WiFi module
	mkdir -p $(TARGET_DIR)/lib/udev/rules.d
	echo 'SUBSYSTEM=="mmc", DRIVER=="sdio", ATTR{power_control}="on"' \
		> $(TARGET_DIR)/lib/udev/rules.d/85-skwifi.rules
endef

define SKWIFI_INNER_PATCH_DIR
	$(call qstrip,$(BR2_GLOBAL_PATCH_DIR))
endef

define SKWIFI_EXTRACT_CMDS
	# Create driver source directory
	mkdir -p $(SKWIFI_SITE)
endef

$(eval $(generic-package))
