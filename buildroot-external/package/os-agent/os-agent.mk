################################################################################
#
# Muthur Command OS Agent (fork of Home Assistant OS Agent)
#
################################################################################

# Pin to a full commit so GitHub archive URLs work without publishing tags.
OS_AGENT_COMMIT = 4ead7a3bb4b47165627a7945870536544ca6b9c6
OS_AGENT_VERSION = $(OS_AGENT_COMMIT)
OS_AGENT_SITE = $(call github,muthur-command,os-agent,$(OS_AGENT_COMMIT))
OS_AGENT_LICENSE = Apache License 2.0
OS_AGENT_LICENSE_FILES = LICENSE
OS_AGENT_GOMOD = github.com/muthur-command/os-agent
OS_AGENT_LDFLAGS = \
	-X main.version=1.9.0-mc.1+g4ead7a3 \
	-X main.board=$(BR2_PACKAGE_OS_AGENT_BOARD)

define OS_AGENT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/contrib/io.muthurcommand.conf \
		$(TARGET_DIR)/etc/dbus-1/system.d/io.muthurcommand.conf
	$(INSTALL) -D -m 0644 $(@D)/contrib/muthur-command-agent.service \
		$(TARGET_DIR)/usr/lib/systemd/system/muthur-command-agent.service
endef

define OS_AGENT_GO_VENDORING
	(cd $(@D); \
		$(OS_AGENT_DL_ENV) $(GO_BIN) env)
endef

OS_AGENT_POST_PATCH_HOOKS += OS_AGENT_GO_VENDORING

$(eval $(golang-package))
