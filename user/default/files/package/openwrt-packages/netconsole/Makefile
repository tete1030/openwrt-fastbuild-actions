include $(TOPDIR)/rules.mk

PKG_NAME:=netconsole
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/netconsole
	SECTION:=base
	CATEGORY:=Network
	TITLE:=NetConsole
	DEPENDS:=+kmod-netconsole +kmod-fs-configfs
endef

define Package/netconsole/description
	Sending kernel messages over network
endef

define Package/netconsole/conffiles
/etc/config/netconsole
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/netconsole/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/netconsole.config $(1)/etc/config/netconsole
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/netconsole.init $(1)/etc/init.d/netconsole
endef

$(eval $(call BuildPackage,netconsole))