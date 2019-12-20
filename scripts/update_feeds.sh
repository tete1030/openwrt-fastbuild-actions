#!/bin/bash

set -eo pipefail

echo "Updating and installing feeds ..."
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a

mkdir -p package/feeds || true
cd package/feeds

if [ -d mentohust ]; then
  git -C mentohust pull --ff
else
  git clone https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk.git mentohust
fi

if [ -d luci-app-mentohust ]; then
  git -C luci-app-mentohust pull --ff
else
  git clone https://github.com/BoringCat/luci-app-mentohust.git luci-app-mentohust
fi