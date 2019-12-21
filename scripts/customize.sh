#!/bin/bash

# Copyright (c) 2019 tete1030
# From https://github.com/tete1030/openwrt-fastbuild-actions

set -eo pipefail

[ -e "${CONFIG_FILE}" ] && cp "${CONFIG_FILE}" openwrt/.config

cd openwrt

(
    if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
        set +eo pipefail
    fi

    find ../patches -type f -name '*.patch' -print0 | sort -z | xargs -t -0 -n 1 patch -p0 --forward -i
    # To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
    true
)

make defconfig
make oldconfig
