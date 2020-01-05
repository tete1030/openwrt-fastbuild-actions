#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

cd openwrt

echo "Updating and installing feeds ..."
get_prev_feeds_suc=0
if [ -d "../openwrt_ori" ]; then
  # Use previous feeds
  (
    set +eo pipefail
    # Use previous feeds status
    cd ../openwrt_ori/
    ./scripts/feeds list -fs > ../openwrt/feeds.conf
  )
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    echo "::warning::Something went wrong in previous builder. Not using last feeds.conf"
    rm feeds.conf
  else
    get_prev_feeds_suc=1
  fi
fi
if [[ ( "${OPT_UPDATE_FEEDS}" == "1" || $get_prev_feeds_suc != 1 ) && -f "../user/current/feeds.conf" ]]; then
  # Only use feeds.conf when specified 'update_feeds'
  cp ../user/current/feeds.conf feeds.conf
fi

./scripts/feeds update -a
./scripts/feeds install -a

mkdir -p package/openwrt-packages

# install_package PACKAGE_DIR GIT_URL REF
install_package() {
  if (( $# < 2 || $# > 3 )); then
    echo "Wrong arguments. Usage: install_package PACKAGE_DIR GIT_URL [REF]" >&2
    exit 1
  fi
  full_package_path="package/openwrt-packages/${1}"
  full_ori_package_path="../openwrt_ori/${full_package_path}"
  if [ -d "${full_package_path}" ]; then
    echo "Duplicated package: ${1}" >&2
    exit 1
  fi
  # Use previous git to preserve version
  if [ -d "${full_ori_package_path}/.git" -a "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
    git clone "${full_ori_package_path}" "${full_package_path}"
    git -C "${full_package_path}" remote set-url origin "${2}"
    git -C "${full_package_path}" fetch
    if [ "${3}" ]; then
      git -C "${full_package_path}" checkout "${3}"
    fi
  else
    git clone "${2}" "${full_package_path}"
    if [ "${3}" ]; then
      git -C "${full_package_path}" checkout "${3}"
    fi
  fi

}

if [ -f "../user/current/packages.txt" ]; then
  source ../user/current/packages.txt
fi
