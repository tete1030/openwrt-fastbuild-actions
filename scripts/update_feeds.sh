#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

echo "Updating and installing feeds ..."
cd openwrt
[ "x${OPT_UPDATE_FEEDS}" != "x1" ] || ./scripts/feeds update -a
./scripts/feeds install -a

mkdir -p package/openwrt-packages || true
if [ -d "package/z-last-build-packages" ]; then
  echo "Migrating from 'package/z-last-build-packages' to 'package/openwrt-packages'"
  mv -nv package/z-last-build-packages/* package/openwrt-packages/
  rm -rf package/z-last-build-packages
fi

# install_package PACKAGE_DIR GIT_URL
install_package() {
  if (( $# != 2 )); then
    echo "Wrong arguments for install_package" >&2
    exit 1
  fi
  if [ -d "${1}" ]; then
    [ "x${OPT_UPDATE_FEEDS}" != "x1" ] || ( git -C "package/openwrt-packages/${1}" reset --hard && git -C "package/openwrt-packages/${1}" pull --ff )
  else
    git -C "package/openwrt-packages" clone "${2}" "${1}"
  fi
}

if [ -f "../user/packages.txt" ]; then
  source ../user/packages.txt
fi
