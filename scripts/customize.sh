#!/bin/bash

set -e

[ -e $CONFIG_FILE ] && cp $CONFIG_FILE openwrt/.config

cd openwrt

# Fix extroot for x86
curl -o package/system/fstools/patches/001-add_propper_rootfs_and_fstab_discovery_on_a_block_device_partitions.patch https://patchwork.ozlabs.org/patch/1082599/raw/

patch package/feeds/packages/netdata/Makefile ../patches/netdata_makefile.patch
patch package/feeds/packages/netdata/files/netdata.init ../patches/netdata_init.patch

patch -p0 < ../patches/libjudy.patch
patch -p0 < ../patches/download_pl.patch

git clone https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk.git package/mentohust
git clone https://github.com/BoringCat/luci-app-mentohust.git package/luci-app-mentohust

make defconfig
make oldconfig