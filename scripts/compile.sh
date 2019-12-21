#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

cd openwrt
if [ "x$1" = "xm" ]; then
    nthread=$(($(nproc) + 1)) 
    echo "${nthread} thread compile: $COMPILE_OPTIONS"
    make $COMPILE_OPTIONS -j${nthread}
elif [ "x$1" = "xs" ]; then
    echo "Fallback to single thread compile: $COMPILE_OPTIONS"
    make $COMPILE_OPTIONS -j1 V=s
else
    echo "Wrong option for compile.sh" >&2
    exit 1
fi
