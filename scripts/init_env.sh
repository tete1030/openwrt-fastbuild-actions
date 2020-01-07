#!/bin/bash

OPENWRT_COMPILE_DIR="${BUILDER_HOME_DIR}/openwrt"
OPENWRT_SOURCE_DIR="${BUILDER_TMP_DIR}/openwrt"
OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"

if [ -d "${OPENWRT_COMPILE_DIR}" ]; then
  OPENWRT_CUR_DIR="${OPENWRT_SOURCE_DIR}"
  if [ -d "${OPENWRT_CUR_DIR}" ]; then
    # probably caused by a failure builder upload
    rm -rf "${OPENWRT_CUR_DIR}"
  fi
fi

echo "::set-env name=OPENWRT_COMPILE_DIR::${OPENWRT_COMPILE_DIR}"
echo "::set-env name=OPENWRT_CUR_DIR::${OPENWRT_CUR_DIR}"
echo "::set-env name=OPENWRT_SOURCE_DIR::${OPENWRT_SOURCE_DIR}"

[ "x${TEST}" != "x1" ] || exit 0

if [ ! -x "$(command -v rsync)" ]; then
    echo "rsync not found, installing for backward compatibility"
    sudo -E apt-get -qq update && sudo -E apt-get -qq install rsync
fi
