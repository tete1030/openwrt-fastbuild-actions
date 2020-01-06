#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

if [ -z "${OPENWRT_DIR}" -o -z "${OPENWRT_WORK_DIR}" -o -z "${OPENWRT_SOURCE_RECONS_DIR}" ]; then
  echo "::error::'OPENWRT_DIR', 'OPENWRT_WORK_DIR' or 'OPENWRT_SOURCE_RECONS_DIR' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_DIR}/bin/targets/x86/64/packages"
  mkdir -p "${OPENWRT_DIR}/bin/packages"
  echo "Dummy firmware" > "${OPENWRT_DIR}/bin/targets/x86/64/firmware.bin"
  echo "Dummy packages" > "${OPENWRT_DIR}/bin/targets/x86/64/packages/packages.tar.gz"
  echo "Dummy packages" > "${OPENWRT_DIR}/bin/packages/packages.tar.gz"
  exit 0
fi

compile() {
    (
        cd "${OPENWRT_WORK_DIR}"
        if [ "x${MODE}" = "xm" ]; then
            nthread=$(($(nproc) + 1)) 
            echo "${nthread} thread compile: $@"
            make -j${nthread} "$@"
        elif [ "x${MODE}" = "xs" ]; then
            echo "Fallback to single thread compile: $@"
            make -j1 V=s "$@"
        else
            echo "No MODE specified" >&2
            exit 1
        fi
    )
}

if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
    compile
else
    compile "package/compile"
    compile "package/index"
fi
