#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_DIR}" -o -z "${OPENWRT_WORK_DIR}" -o -z "${OPENWRT_SOURCE_RECONS_DIR}" ]; then
  echo "::error::'OPENWRT_DIR', 'OPENWRT_WORK_DIR' or 'OPENWRT_SOURCE_RECONS_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

if [ -d "${OPENWRT_SOURCE_RECONS_DIR}" ]; then
    rm -rf "${OPENWRT_SOURCE_RECONS_DIR}"
fi
