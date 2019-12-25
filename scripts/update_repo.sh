#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -d openwrt ]; then
  git -C openwrt pull --ff
else
  if [ -z "${REPO_URL}" -o -z "${REPO_BRANCH}" ]; then
    echo "'REPO_URL' or 'REPO_BRANCH' is empty" >&2
    exit 1
  fi
  git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt
fi
