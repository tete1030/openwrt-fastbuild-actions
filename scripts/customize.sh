#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" -o -z "${OPENWRT_CUR_DIR}" -o -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

cp user/current/config.diff "${OPENWRT_CUR_DIR}/.config"

if [ -n "$(ls -A user/current/patches 2>/dev/null)" ]; then
(
    if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
        set +eo pipefail
    fi

    find user/current/patches -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d '${OPENWRT_CUR_DIR}' -p0 --forward"
    # To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
    true
)
fi

if [ -n "$(ls -A user/current/files 2>/dev/null)" ]; then
  cp -r user/current/files "${OPENWRT_CUR_DIR}/files"
fi

(
    cd "${OPENWRT_CUR_DIR}"
    make defconfig
    make oldconfig
)

# Restore build cache and timestamps
if [ "x${OPENWRT_CUR_DIR}" != "x${OPENWRT_COMPILE_DIR}" ]; then
(
    if [ ! -x "$(command -v rsync)" ]; then
        echo "rsync not found, installing for backward compatibility"
        sudo -E apt-get -qq update && sudo -E apt-get -qq install rsync
    fi
    # sync files by comparing checksum
    rsync -ca --no-t --delete \
        --exclude="/bin" \
        --exclude="/dl" \
        --exclude="/tmp" \
        --exclude="/build_dir" \
        --exclude="/staging_dir" \
        --exclude="/toolchain" \
        --exclude="/logs" \
        --exclude="*.o" \
        --exclude="key-build*" \
        "${OPENWRT_CUR_DIR}/" "${OPENWRT_COMPILE_DIR}/"

    rm -rf "${OPENWRT_CUR_DIR}"
    OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
    echo "::set-env name=OPENWRT_CUR_DIR::${OPENWRT_CUR_DIR}"
)
fi