################################################################################
#
# rockchip-mpp
#
################################################################################

ROCKCHIP_MPP_VERSION = main
ROCKCHIP_MPP_SITE = https://github.com/mcos-platform/mpp.git
ROCKCHIP_MPP_SITE_METHOD = git
ROCKCHIP_MPP_LICENSE = Apache-2.0, MIT
ROCKCHIP_MPP_LICENSE_FILES = LICENSES/Apache-2.0 LICENSES/MIT

ROCKCHIP_MPP_DEPENDENCIES = libdrm

ROCKCHIP_MPP_INSTALL_STAGING = YES

# Build configuration
ROCKCHIP_MPP_CONF_OPTS = \
	-DRKPLATFORM=ON \
	-DHAVE_DRM=ON

ifeq ($(BR2_PACKAGE_ROCKCHIP_MPP_ALLOCATOR_DRM),y)
ROCKCHIP_MPP_CONF_OPTS += -DHAVE_DRM=ON
endif

ifeq ($(BR2_PACKAGE_ROCKCHIP_MPP_TESTS),y)
ROCKCHIP_MPP_CONF_OPTS += -DBUILD_TEST=ON
endif

# Upstream .gitignore excludes /build; version.in is required by CMake.
define ROCKCHIP_MPP_INSTALL_VERSION_IN
	mkdir -p $(@D)/build/cmake
	$(INSTALL) -D -m 0644 $(ROCKCHIP_MPP_PKGDIR)/build/cmake/version.in \
		$(@D)/build/cmake/version.in
endef
ROCKCHIP_MPP_POST_EXTRACT_HOOKS += ROCKCHIP_MPP_INSTALL_VERSION_IN

# Remove noisy debug logs
define ROCKCHIP_MPP_REMOVE_NOISY_LOGS
	sed -i -e "/pp_enable %d/d" \
		$(@D)/mpp/hal/vpu/jpegd/hal_jpegd_vdpu2.c || true
endef
ROCKCHIP_MPP_POST_RSYNC_HOOKS += ROCKCHIP_MPP_REMOVE_NOISY_LOGS

# Remove legacy VPU library
define ROCKCHIP_MPP_TARGET_INSTALL_REMOVE_VPU
	rm -f $(TARGET_DIR)/usr/lib/librockchip_vpu.so*
endef
ROCKCHIP_MPP_POST_INSTALL_TARGET_HOOKS += ROCKCHIP_MPP_TARGET_INSTALL_REMOVE_VPU

$(eval $(cmake-package))