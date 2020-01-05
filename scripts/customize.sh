#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

cd openwrt

cp ../user/current/config.diff .config

if [ "$(ls -A ../user/current/patches 2>/dev/null)" ]; then
(
    if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
        set +eo pipefail
    fi

    find ../user/current/patches -type f -name '*.patch' -print0 | sort -z | xargs -t -0 -n 1 patch -p0 --forward -i
    # To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
    true
)
fi

if [ "$(ls -A ../user/current/files 2>/dev/null)" ]; then
  cp -r ../user/current/files files
fi

make defconfig
make oldconfig

# Restore build cache and timestamps
if [ -d "../openwrt_ori" ]; then
(
    cd ..
    # sync files by comparing checksum
    rsync -ca --no-t --delete \
        --exclude="/dl" \
        --exclude="/tmp" \
        --exclude="/build_dir" \
        --exclude="/staging_dir" \
        --exclude="/toolchain" \
        --exclude="/logs" \
        openwrt/ openwrt_ori/

    mv openwrt openwrt_new
    mv openwrt_ori openwrt
    rm -rf openwrt_new
)
fi