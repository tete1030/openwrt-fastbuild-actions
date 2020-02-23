include $(TOPDIR)/rules.mk

PKG_NAME:=libJudy
PKG_VERSION:=1.0.5
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/judy-$(PKG_VERSION)
PKG_SOURCE:=Judy-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=@SF/judy
PKG_MD5SUM:=115a0d26302676e962ae2f70ec484a54
PKG_CAT:=zcat

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/libJudy
	SECTION:=base
	CATEGORY:=Libraries
	DEFAULT:=n
	TITLE:=General purpose dynamic array
	URL:=http://judy.sourceforge.net/
endef


MAKE_FLAGS += \
        HOSTCC="$(HOSTCC)" \
        HOST_CFLAGS="-DJU_64BIT -m64 $(HOST_CFLAGS)"

define Build/Configure
	$(call Build/Configure/Default,--prefix=/usr --enable-64-bit)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/Judy.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libJudy.{a,so*} $(1)/usr/lib/
endef

define Package/libJudy/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libJudy.so.* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libJudy))