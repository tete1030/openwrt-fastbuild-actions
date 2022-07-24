#
# Copyright (C) 2010-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gocryptfs
PKG_VERSION:=2.2.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/rfjakob/$(PKG_NAME)/archive/v$(PKG_VERSION)
PKG_HASH:=b8459db4b62c8cec311a957bb808a44d9626b4fda219bd9098b1ebefb8d6f00b

PKG_MAINTAINER:=Alexander Egorenkov <egorenar-dev@posteo.net>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/rfjakob/gocryptfs/v2
GO_PKG_BUILD_PKG:=github.com/rfjakob/gocryptfs/v2

GO_PKG_LDFLAGS_X:= \
	main.GitVersion=$(PKG_VERSION) \
	main.BuildDate=$(SOURCE_DATE_EPOCH) \
	main.GitVersionFuse="[unknown]"

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/gocryptfs
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Encryption
  TITLE:=An encrypted overlay filesystem written in Go
  URL:=https://nuetzlich.net/gocryptfs/
  DEPENDS:=$(GO_ARCH_DEPENDS) +libopenssl +libfuse +fuse-utils +kmod-fuse
endef

define Package/gocryptfs/description
  An encrypted overlay filesystem written in Go
endef

define Package/gocryptfs/install
	$(call GoPackage/Package/Install/Bin,$(1))
endef

$(eval $(call GoBinPackage,gocryptfs))
$(eval $(call BuildPackage,gocryptfs))