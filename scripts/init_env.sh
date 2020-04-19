#!/bin/bash

# shellcheck disable=SC1090
source "${BUILDER_WORK_DIR}/scripts/lib/gaction.sh"

OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
# if we are not fresh building
if [ -d "${OPENWRT_COMPILE_DIR}" ]; then
  OPENWRT_CUR_DIR="${OPENWRT_SOURCE_DIR}"
  if [ -d "${OPENWRT_CUR_DIR}" ]; then
    # probably caused by a broken builder upload
    rm -rf "${OPENWRT_CUR_DIR}"
  fi
fi

_set_env OPENWRT_CUR_DIR

[ "x${TEST}" != "x1" ] || exit 0

if [ ! -x "$(command -v rsync)" ]; then
    echo "rsync not found, installing for backward compatibility"
    sudo -E apt-get -qq update && sudo -E apt-get -qq install rsync
fi
