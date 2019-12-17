#!/bin/bash

set -eo pipefail

[ -e $CONFIG_FILE ] && cp $CONFIG_FILE openwrt/.config

cd openwrt

if [ x"$NONSTRICT_PATCH" = x"1" ]; then
    set +eo pipefail
fi

find ../patches -type f -name '*.patch' -print0 | sort -z | xargs -t -0 -n 1 patch -p0 --forward -i

set -eo pipefail

make defconfig
make oldconfig
