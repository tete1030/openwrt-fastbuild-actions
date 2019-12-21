#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

cd openwrt
if [ "x$1" = "xm" ]; then
    echo -e "$(nproc) thread compile: $COMPILE_OPTIONS"
    make $COMPILE_OPTIONS -j$(nproc)
else
    echo "Fallback to single thread compile: $COMPILE_OPTIONS"
    make $COMPILE_OPTIONS -j1 V=s
fi
