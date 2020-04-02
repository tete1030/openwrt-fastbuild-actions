define KernelPackage/netconsole
  SUBMENU:=Other modules
  TITLE:=NetConsole
  DEPENDS:=+kmod-fs-configfs
  KCONFIG:= \
        CONFIG_NETCONSOLE \
        CONFIG_NETCONSOLE_DYNAMIC=y
  FILES:=$(LINUX_DIR)/drivers/net/netconsole.ko
  AUTOLOAD:=$(call AutoLoad,30,netconsole)
endef

define KernelPackage/netconsole/description
 Kernel module that sends all kernel log messages over the network
endef

$(eval $(call KernelPackage,netconsole))
