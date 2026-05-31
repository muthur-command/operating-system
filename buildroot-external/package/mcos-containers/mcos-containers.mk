################################################################################
#
# MCOS containers (data partition: Supervisor + plugin containers)
#
################################################################################

MCOS_CONTAINERS_VERSION = 1.0.0
MCOS_CONTAINERS_LICENSE = Apache License 2.0
# MCOS_CONTAINERS_LICENSE_FILES = $(BR2_EXTERNAL_MCOS_PATH)/../LICENSE
MCOS_CONTAINERS_SITE = $(BR2_EXTERNAL_MCOS_PATH)/package/mcos-containers
MCOS_CONTAINERS_SITE_METHOD = local
MCOS_CONTAINERS_VERSION_URL = https://version.muthur-command.com/
ifeq ($(BR2_PACKAGE_MCOS_CONTAINERS_CHANNEL_STABLE),y)
MCOS_CONTAINERS_VERSION_CHANNEL = stable
else ifeq ($(BR2_PACKAGE_MCOS_CONTAINERS_CHANNEL_BETA),y)
MCOS_CONTAINERS_VERSION_CHANNEL = beta
else ifeq ($(BR2_PACKAGE_MCOS_CONTAINERS_CHANNEL_DEV),y)
MCOS_CONTAINERS_VERSION_CHANNEL = dev
endif

MCOS_CONTAINERS_CONTAINER_IMAGES_ARCH = supervisor dns audio cli multicast observer mc_bd
MCOS_CONTAINERS_CONTAINER_IMAGES_NOARCH = mc_fd postgresql redis

define MCOS_CONTAINERS_CONFIGURE_CMDS
	$(BR2_EXTERNAL_MCOS_PATH)/package/mcos-containers/fetch-version-json.sh \
		$(MCOS_CONTAINERS_VERSION_URL)$(MCOS_CONTAINERS_VERSION_CHANNEL).json \
		$(@D)/version.json
endef

define MCOS_CONTAINERS_BUILD_CMDS
	$(Q)mkdir -p $(@D)/images
	$(Q)mkdir -p $(MCOS_CONTAINERS_DL_DIR)
	$(foreach image,$(MCOS_CONTAINERS_CONTAINER_IMAGES_ARCH),\
		$(BR2_EXTERNAL_MCOS_PATH)/package/mcos-containers/fetch-container-image.sh \
			$(BR2_PACKAGE_MCOS_CONTAINERS_ARCH) $(BR2_PACKAGE_MCOS_CONTAINERS_MACHINE) $(@D)/version.json $(image) "$(MCOS_CONTAINERS_DL_DIR)" "$(@D)/images"
	)
	$(foreach image,$(MCOS_CONTAINERS_CONTAINER_IMAGES_NOARCH),\
		$(BR2_EXTERNAL_MCOS_PATH)/package/mcos-containers/fetch-container-image.sh \
			$(BR2_PACKAGE_MCOS_CONTAINERS_ARCH) $(BR2_PACKAGE_MCOS_CONTAINERS_MACHINE) $(@D)/version.json $(image) "$(MCOS_CONTAINERS_DL_DIR)" "$(@D)/images"
	)
endef

MCOS_CONTAINERS_INSTALL_IMAGES = YES

define MCOS_CONTAINERS_INSTALL_IMAGES_CMDS
	$(BR2_EXTERNAL_MCOS_PATH)/package/mcos-containers/create-data-partition.sh \
		$(@D) $(BINARIES_DIR) $(MCOS_CONTAINERS_VERSION_CHANNEL) $(DOCKER_ENGINE_VERSION)
endef

$(eval $(generic-package))
