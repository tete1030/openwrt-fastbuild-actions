#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

echo "Updating and installing feeds ..."
# priority when update_feeds=false: prev > user > legacy (> default)
# priority when update_feeds=true:  user > legacy (> default), no prev

if [ -f "${BUILDER_PROFILE_DIR}/files/feeds.conf" ]; then
  cp "${BUILDER_PROFILE_DIR}/files/feeds.conf" "${OPENWRT_CUR_DIR}/feeds.conf"
fi

# Backup feeds.conf file
if [ -f "${OPENWRT_CUR_DIR}/feeds.conf" ]; then
  cp "${OPENWRT_CUR_DIR}/feeds.conf" "${BUILDER_TMP_DIR}/feeds.conf.bak"
fi

if [ "x${OPENWRT_CUR_DIR}" != "x${OPENWRT_COMPILE_DIR}" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
  # Use previous feeds
  (
    set +eo pipefail
    # Use previous feeds status
    cd "${OPENWRT_COMPILE_DIR}" && ./scripts/feeds list -fs > "${BUILDER_TMP_DIR}/feeds.conf.prev"
  )
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    echo "::warning::Something went wrong in previous builder. Not using last feeds.conf"
    rm "${BUILDER_TMP_DIR}/feeds.conf.prev" || true
  else
    mv "${BUILDER_TMP_DIR}/feeds.conf.prev" "${OPENWRT_CUR_DIR}/feeds.conf"
  fi
fi

(
  cd "${OPENWRT_CUR_DIR}"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
)

if [ -f "${BUILDER_TMP_DIR}/feeds.conf.bak" ]; then
  mv "${BUILDER_TMP_DIR}/feeds.conf.bak" "${OPENWRT_CUR_DIR}/feeds.conf" 
fi

PACKAGE_DIR="${OPENWRT_CUR_DIR}/package/openwrt-packages"
mkdir -p "${PACKAGE_DIR}"

# install_package PACKAGE_DIR GIT_URL REF
install_package() {
  if (( $# < 2 || $# > 3 )); then
    echo "Wrong arguments. Usage: install_package PACKAGE_DIR GIT_URL [REF]" >&2
    exit 1
  fi
  PACKAGE_PATH="${PACKAGE_DIR}/${1}"
  full_cur_package_path="${OPENWRT_CUR_DIR}/${PACKAGE_PATH}"
  full_compile_package_path="${OPENWRT_COMPILE_DIR}/${PACKAGE_PATH}"
  if [ -d "${full_cur_package_path}" ]; then
    echo "Duplicated package: ${1}" >&2
    exit 1
  fi
  # Use previous git to preserve version
  if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" ] && [ -d "${full_compile_package_path}/.git" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
    git clone "${full_compile_package_path}" "${full_cur_package_path}"
    git -C "${full_cur_package_path}" remote set-url origin "${2}"
    git -C "${full_cur_package_path}" fetch
  else
    git clone "${2}" "${full_cur_package_path}"
  fi

  if [ -n "${3}" ]; then
    git -C "${full_cur_package_path}" checkout "${3}"
  fi
}

if [ -f "${BUILDER_PROFILE_DIR}/packages.txt" ]; then
  while IFS= read -r line; do
    if [ -n "${line// }" ] && [[ ! "${line}" =~ ^[[:blank:]]*\# ]] ; then
      # shellcheck disable=SC2086
      install_package ${line}
    fi
  done <"${BUILDER_PROFILE_DIR}/packages.txt"
fi
