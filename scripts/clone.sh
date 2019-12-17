#!/bin/bash

set -eo pipefail

git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt

echo "Updating and installing feeds ..."
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a

git clone https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk.git package/mentohust
git clone https://github.com/BoringCat/luci-app-mentohust.git package/luci-app-mentohust
