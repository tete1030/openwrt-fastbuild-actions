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

LBITS = $(shell $(TARGET_CC) -dM -E - </dev/null | grep -q "__LP64__" && echo 64 || echo 32)

ifeq ($(LBITS),64)
	CFLAGS_64= -DJU_64BIT
else
	CFLAGS_64= -UJU_64BIT
endif
TARGET_CFLAGS+= $(CFLAGS_64)

MAKE_FLAGS += \
        HOSTCC="$(HOSTCC)" \
        HOST_CFLAGS="$(HOST_CFLAGS) $(CFLAGS_64)"

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