################################################################################
#
# Muthur Command OS Agent
#
################################################################################

OS_AGENT_VERSION = 2026.05.1
OS_AGENT_SITE = $(call github,muthur-command,os-agent,$(OS_AGENT_VERSION))
OS_AGENT_LICENSE = Apache License 2.0
OS_AGENT_LICENSE_FILES = LICENSE
OS_AGENT_GOMOD = github.com/muthur-command/os-agent
OS_AGENT_LDFLAGS = \
	-X main.version=2026.05.1 \
	-X main.board=$(BR2_PACKAGE_OS_AGENT_BOARD)

define OS_AGENT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/contrib/io.muthurcommand.conf \
		$(TARGET_DIR)/etc/dbus-1/system.d/io.muthurcommand.conf
	$(INSTALL) -D -m 0644 $(@D)/contrib/muthur-command-agent.service \
		$(TARGET_DIR)/usr/lib/systemd/system/muthur-command-agent.service
endef

define OS_AGENT_GO_VENDORING
	(cd $(@D); \
		$(HOST_GO_COMMON_ENV) \
		GOPROXY=direct \
		$(GO_BIN) mod vendor)
endef

OS_AGENT_POST_PATCH_HOOKS += OS_AGENT_GO_VENDORING

$(eval $(golang-package))
