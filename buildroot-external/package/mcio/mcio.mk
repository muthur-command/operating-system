################################################################################
#
# MCOS (data partition: Supervisor + plugin containers)
#
################################################################################

MCIO_VERSION = 1.0.0
MCIO_LICENSE = Apache License 2.0
# MCIO_LICENSE_FILES = $(BR2_EXTERNAL_MCOS_PATH)/../LICENSE
MCIO_SITE = $(BR2_EXTERNAL_MCOS_PATH)/package/mcio
MCIO_SITE_METHOD = local
MCIO_VERSION_URL = "https://version.muthur-command.com/"
ifeq ($(BR2_PACKAGE_MCIO_CHANNEL_STABLE),y)
MCIO_VERSION_CHANNEL = "stable"
else ifeq ($(BR2_PACKAGE_MCIO_CHANNEL_BETA),y)
MCIO_VERSION_CHANNEL = "beta"
else ifeq ($(BR2_PACKAGE_MCIO_CHANNEL_DEV),y)
MCIO_VERSION_CHANNEL = "dev"
endif

MCIO_CONTAINER_IMAGES_ARCH = supervisor dns audio cli multicast observer mc_bd
MCIO_CONTAINER_IMAGES_NOARCH = mc_fd postgresql redis

define MCIO_CONFIGURE_CMDS
	curl -s $(MCIO_VERSION_URL)$(MCIO_VERSION_CHANNEL)".json" > $(@D)/version.json
endef

define MCIO_BUILD_CMDS
	$(Q)mkdir -p $(@D)/images
	$(Q)mkdir -p $(MCIO_DL_DIR)
	$(foreach image,$(MCIO_CONTAINER_IMAGES_ARCH),\
		$(BR2_EXTERNAL_MCOS_PATH)/package/mcio/fetch-container-image.sh \
			$(BR2_PACKAGE_MCIO_ARCH) $(BR2_PACKAGE_MCIO_MACHINE) $(@D)/version.json $(image) "$(MCIO_DL_DIR)" "$(@D)/images"
	)
	$(foreach image,$(MCIO_CONTAINER_IMAGES_NOARCH),\
		$(BR2_EXTERNAL_MCOS_PATH)/package/mcio/fetch-container-image.sh \
			$(BR2_PACKAGE_MCIO_ARCH) $(BR2_PACKAGE_MCIO_MACHINE) $(@D)/version.json $(image) "$(MCIO_DL_DIR)" "$(@D)/images"
	)
endef

MCIO_INSTALL_IMAGES = YES

define MCIO_INSTALL_IMAGES_CMDS
	$(BR2_EXTERNAL_MCOS_PATH)/package/mcio/create-data-partition.sh "$(@D)" "$(BINARIES_DIR)" "$(MCIO_VERSION_CHANNEL)" "$(DOCKER_ENGINE_VERSION)"
endef

$(eval $(generic-package))
