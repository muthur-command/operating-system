################################################################################
#
# Muthur Command OS — tempio (host tool)
#
################################################################################

TEMPIO_VERSION = mc_2026.04.1
TEMPIO_SITE = $(call github,muthur-command,tempio,$(TEMPIO_VERSION))
TEMPIO_LICENSE = Apache License 2.0
TEMPIO_LICENSE_FILES = LICENSE
TEMPIO_GOMOD = github.com/muthur-command/tempio
TEMPIO_LDFLAGS = -X main.version=$(TEMPIO_VERSION)

define TEMPIO_GO_VENDORING
	(cd $(@D); \
		$(HOST_DIR)/bin/go mod vendor)
endef

TEMPIO_POST_PATCH_HOOKS += TEMPIO_GO_VENDORING

$(eval $(golang-package))
$(eval $(host-golang-package))
