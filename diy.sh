#!/bin/bash

cd openwrt

patch package/feeds/packages/netdata/Makefile ../patches/netdata_makefile.patch
patch package/feeds/packages/netdata/files/netdata.init ../patches/netdata_init.patch

patch -p0 < ../patches/libjudy.patch
patch -p0 < ../patches/download_pl.patch

git clone https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk.git package/mentohust
git clone https://github.com/BoringCat/luci-app-mentohust.git package/luci-app-mentohust
