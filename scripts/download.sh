#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

if [ -z "${OPENWRT_DIR}" -o -z "${OPENWRT_WORK_DIR}" ]; then
  echo "'OPENWRT_DIR' or 'OPENWRT_WORK_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

cd "${OPENWRT_WORK_DIR}"
make download -j8
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;
