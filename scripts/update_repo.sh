#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${REPO_URL}" -o -z "${REPO_BRANCH}" ]; then
  echo "'REPO_URL' or 'REPO_BRANCH' is empty" >&2
  exit 1
fi

# The following will reset all non-building changes,
# including some not managed by git, preseve timestamps
# of unchanged files (even if their timestamp changed)
# and make changed files' timestamps most recent
if [ -d openwrt ]; then
  if [ ! -d openwrt_ori ]; then
    mv openwrt openwrt_ori
  else
    # probably caused by a failure builder upload, we should use openwrt_ori
    rm -rf openwrt
  fi
fi

if [ -d openwrt_ori -a "x${OPT_UPDATE_REPO}" != "x1" ]; then
  git clone openwrt_ori openwrt
  git -C openwrt remote set-url origin "${REPO_URL}"
  git -C openwrt fetch
  git -C openwrt checkout "${REPO_BRANCH}"
else
  git clone -b "${REPO_BRANCH}" "${REPO_URL}" openwrt
fi
