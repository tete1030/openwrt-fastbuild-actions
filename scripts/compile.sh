#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages"
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/packages"
  echo "Dummy firmware" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/firmware.bin"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages/packages.tar.gz"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/packages/packages.tar.gz"
  exit 0
fi

compile() {
  (
    cd "${OPENWRT_CUR_DIR}"
    if [ "x${MODE}" = "xm" ]; then
      local nthread=$(($(nproc) + 1)) 
      echo "${nthread} thread compile: $*"
      make -j${nthread} "$@"
    elif [ "x${MODE}" = "xs" ]; then
      echo "Fallback to single thread compile: $*"
      make -j1 V=s "$@"
    else
      echo "No MODE specified" >&2
      exit 1
    fi
  )
}

echo "Executing pre_compile.sh"
if [ -f "${BUILDER_PROFILE_DIR}/pre_compile.sh" ]; then
  /bin/bash "${BUILDER_PROFILE_DIR}/pre_compile.sh"
fi

echo "Compiling..."
if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
  compile
else
  compile "package/compile"
  compile "package/index"
fi
