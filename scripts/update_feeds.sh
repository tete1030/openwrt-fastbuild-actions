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

echo "Updating and installing feeds ..."
get_prev_feeds_suc=0
if [ "x${OPENWRT_CUR_DIR}" != "x${OPENWRT_COMPILE_DIR}" ]; then
  # Use previous feeds
  (
    set +eo pipefail
    # Use previous feeds status
    cd "${OPENWRT_COMPILE_DIR}" && ./scripts/feeds list -fs > "${BUILDER_TMP_DIR}/feeds.conf"
  )
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    echo "::warning::Something went wrong in previous builder. Not using last feeds.conf"
    rm "${BUILDER_TMP_DIR}/feeds.conf" || true
  else
    mv "${BUILDER_TMP_DIR}/feeds.conf" "${OPENWRT_CUR_DIR}/feeds.conf"
    get_prev_feeds_suc=1
  fi
fi
if [[ ( "${OPT_UPDATE_FEEDS}" == "1" || $get_prev_feeds_suc != 1 ) && -f "${BUILDER_PROFILE_DIR}/feeds.conf" ]]; then
  # Only use feeds.conf when specified 'update_feeds'
  cp "${BUILDER_PROFILE_DIR}/feeds.conf" "${OPENWRT_CUR_DIR}/feeds.conf"
fi

(
  cd "${OPENWRT_CUR_DIR}"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
)

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
  if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" -a -d "${full_compile_package_path}/.git" -a "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
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
  source "${BUILDER_PROFILE_DIR}/packages.txt"
fi
