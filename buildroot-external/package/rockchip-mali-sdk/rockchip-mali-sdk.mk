################################################################################
#
# rockchip-mali-sdk
#
# Mali GPU driver for Rockchip RK3576 (Mali G52)
# Uses pre-built libraries from mcos-platform/libmali repository
################################################################################

ROCKCHIP_MALI_SDK_VERSION = main
ROCKCHIP_MALI_SDK_SITE = https://github.com/mcos-platform/libmali.git
ROCKCHIP_MALI_SDK_SITE_METHOD = git

ROCKCHIP_MALI_SDK_LICENSE = ARM-EULA
ROCKCHIP_MALI_SDK_LICENSE_FILES = END_USER_LICENCE_AGREEMENT.txt

# RK3576 uses Mali G52 with the GBM backend.
ROCKCHIP_MALI_SDK_LIB_NAME = libmali-bifrost-g52-g2p0-gbm.so
ROCKCHIP_MALI_SDK_LIB_FULL = $(ROCKCHIP_MALI_SDK_LIB_NAME)

# Virtual package providers
ifeq ($(BR2_PACKAGE_ROCKCHIP_MALI_SDK_HAS_EGL),y)
ROCKCHIP_MALI_SDK_PROVIDES += libegl
endif

ifeq ($(BR2_PACKAGE_ROCKCHIP_MALI_SDK_HAS_GLES),y)
ROCKCHIP_MALI_SDK_PROVIDES += libgles
endif

ifeq ($(BR2_PACKAGE_ROCKCHIP_MALI_SDK_HAS_GBM),y)
ROCKCHIP_MALI_SDK_PROVIDES += libgbm
endif

ifeq ($(BR2_PACKAGE_ROCKCHIP_MALI_SDK_HAS_OPENCL),y)
ROCKCHIP_MALI_SDK_PROVIDES += libopencl
endif

# Dependencies
ROCKCHIP_MALI_SDK_DEPENDENCIES = libdrm

# Symlinks to install
ROCKCHIP_MALI_SDK_SYMLINKS = \
	libmali.so.1 \
	libMali.so \
	libEGL.so \
	libgbm.so \
	libGLESv1_CM.so \
	libGLESv2.so

# Install library files and headers from the git tree
define ROCKCHIP_MALI_SDK_INSTALL_TARGET_CMDS
	# Create target directories
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/lib

	# Install the GBM Mali library
	$(INSTALL) -m 0755 \
		$(@D)/lib/aarch64-linux-gnu/$(ROCKCHIP_MALI_SDK_LIB_FULL) \
		$(TARGET_DIR)/usr/lib/

	# Create compatibility symlinks
	ln -sf $(ROCKCHIP_MALI_SDK_LIB_FULL) $(TARGET_DIR)/usr/lib/libmali.so.1
	$(foreach symlink,$(ROCKCHIP_MALI_SDK_SYMLINKS), \
		ln -sf $(ROCKCHIP_MALI_SDK_LIB_FULL) $(TARGET_DIR)/usr/lib/$(symlink) ; \
	)

	# Install headers
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/include/EGL
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/include/GLES
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/include/GLES2
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/include/GLES3
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/include/KHR

	$(INSTALL) -m 0644 $(@D)/include/EGL/* $(TARGET_DIR)/usr/include/EGL/
	$(INSTALL) -m 0644 $(@D)/include/GLES/* $(TARGET_DIR)/usr/include/GLES/
	$(INSTALL) -m 0644 $(@D)/include/GLES2/* $(TARGET_DIR)/usr/include/GLES2/
	$(INSTALL) -m 0644 $(@D)/include/GLES3/* $(TARGET_DIR)/usr/include/GLES3/
	$(INSTALL) -m 0644 $(@D)/include/KHR/* $(TARGET_DIR)/usr/include/KHR/

	# gbm.h is provided by libdrm; do not copy from mali.
	# pkgconfig files come from other packages, not mali.
endef

define ROCKCHIP_MALI_SDK_INSTALL_STAGING_CMDS
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/lib
	$(INSTALL) -m 0755 \
		$(@D)/lib/aarch64-linux-gnu/$(ROCKCHIP_MALI_SDK_LIB_FULL) \
		$(STAGING_DIR)/usr/lib/
	ln -sf $(ROCKCHIP_MALI_SDK_LIB_FULL) $(STAGING_DIR)/usr/lib/libmali.so.1
	$(foreach symlink,$(ROCKCHIP_MALI_SDK_SYMLINKS), \
		ln -sf $(ROCKCHIP_MALI_SDK_LIB_FULL) $(STAGING_DIR)/usr/lib/$(symlink) ; \
	)
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/include/EGL
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/include/GLES
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/include/GLES2
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/include/GLES3
	$(INSTALL) -d -m 0755 $(STAGING_DIR)/usr/include/KHR
	$(INSTALL) -m 0644 $(@D)/include/EGL/* $(STAGING_DIR)/usr/include/EGL/
	$(INSTALL) -m 0644 $(@D)/include/GLES/* $(STAGING_DIR)/usr/include/GLES/
	$(INSTALL) -m 0644 $(@D)/include/GLES2/* $(STAGING_DIR)/usr/include/GLES2/
	$(INSTALL) -m 0644 $(@D)/include/GLES3/* $(STAGING_DIR)/usr/include/GLES3/
	$(INSTALL) -m 0644 $(@D)/include/KHR/* $(STAGING_DIR)/usr/include/KHR/
	# gbm.h is provided by libdrm; do not copy from mali.
	# pkgconfig files come from other packages, not mali.
endef

$(eval $(generic-package))
