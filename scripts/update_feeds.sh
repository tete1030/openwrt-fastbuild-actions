#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_DIR}" -o -z "${OPENWRT_WORK_DIR}" ]; then
  echo "'OPENWRT_DIR' or 'OPENWRT_WORK_DIR' is empty" >&2
  exit 1
fi

echo "Updating and installing feeds ..."
get_prev_feeds_suc=0
if [ "x${OPENWRT_WORK_DIR}" != "x${OPENWRT_DIR}" ]; then
  # Use previous feeds
  (
    set +eo pipefail
    # Use previous feeds status
    cd "${OPENWRT_DIR}"
    ./scripts/feeds list -fs > /tmp/feeds.conf
  )
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    echo "::warning::Something went wrong in previous builder. Not using last feeds.conf"
    rm /tmp/feeds.conf || true
  else
    mv /tmp/feeds.conf "${OPENWRT_WORK_DIR}/feeds.conf"
    get_prev_feeds_suc=1
  fi
fi
if [[ ( "${OPT_UPDATE_FEEDS}" == "1" || $get_prev_feeds_suc != 1 ) && -f "user/current/feeds.conf" ]]; then
  # Only use feeds.conf when specified 'update_feeds'
  cp user/current/feeds.conf "${OPENWRT_WORK_DIR}/feeds.conf"
fi

(
  cd "${OPENWRT_WORK_DIR}"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
)

PACKAGE_DIR="package/openwrt-packages"
mkdir -p "${OPENWRT_WORK_DIR}/${PACKAGE_DIR}"

# install_package PACKAGE_DIR GIT_URL REF
install_package() {
  if (( $# < 2 || $# > 3 )); then
    echo "Wrong arguments. Usage: install_package PACKAGE_DIR GIT_URL [REF]" >&2
    exit 1
  fi
  PACKAGE_PATH="${PACKAGE_DIR}/${1}"
  full_work_package_path="${OPENWRT_WORK_DIR}/${PACKAGE_PATH}"
  full_package_path="${OPENWRT_DIR}/${PACKAGE_PATH}"
  if [ -d "${full_work_package_path}" ]; then
    echo "Duplicated package: ${1}" >&2
    exit 1
  fi
  # Use previous git to preserve version
  if [ "x${full_work_package_path}" != "x${full_package_path}" -a -d "${full_package_path}/.git" -a "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
    git clone "${full_package_path}" "${full_work_package_path}"
    git -C "${full_work_package_path}" remote set-url origin "${2}"
    git -C "${full_work_package_path}" fetch
  else
    git clone "${2}" "${full_work_package_path}"
  fi

  if [ -n "${3}" ]; then
    git -C "${full_work_package_path}" checkout "${3}"
  fi
}

if [ -f "user/current/packages.txt" ]; then
  source user/current/packages.txt
fi
