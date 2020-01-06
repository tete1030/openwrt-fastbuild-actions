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

cp user/current/config.diff "${OPENWRT_WORK_DIR}/.config"

if [ -n "$(ls -A user/current/patches 2>/dev/null)" ]; then
(
    if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
        set +eo pipefail
    fi

    find user/current/patches -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d '${OPENWRT_WORK_DIR}' -p0 --forward"
    # To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
    true
)
fi

if [ -n "$(ls -A user/current/files 2>/dev/null)" ]; then
  cp -r user/current/files "${OPENWRT_WORK_DIR}/files"
fi

(
    cd "${OPENWRT_WORK_DIR}"
    make defconfig
    make oldconfig
)

# Restore build cache and timestamps
if [ "x${OPENWRT_WORK_DIR}" != "x${OPENWRT_DIR}" ]; then
(
    # sync files by comparing checksum
    rsync -ca --no-t --delete \
        --exclude="/bin" \
        --exclude="/dl" \
        --exclude="/tmp" \
        --exclude="/build_dir" \
        --exclude="/staging_dir" \
        --exclude="/toolchain" \
        --exclude="/logs" \
        "${OPENWRT_WORK_DIR}/" "${OPENWRT_DIR}/"

    rm -rf "${OPENWRT_WORK_DIR}"
    OPENWRT_WORK_DIR="${OPENWRT_DIR}"
    echo "::set-env name=OPENWRT_WORK_DIR::${OPENWRT_WORK_DIR}"
)
fi