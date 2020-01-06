#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

link_bin() {
  BIN_DIR="${OPENWRT_DIR}/bin"
  BIN_MOUNT_POINT="$(pwd)/openwrt_bin"

  if mountpoint "${BIN_MOUNT_POINT}" ; then
    if [[ ! -L "${BIN_DIR}" || ! -d "${BIN_DIR}" || "$(readlink "${BIN_DIR}")" != "${BIN_MOUNT_POINT}" ]]; then
      echo "'bin' link does not exist, creating"
      rm -rf "${BIN_DIR}" || true
      ln -sf "${BIN_MOUNT_POINT}" "${BIN_DIR}"
    fi
  else
    echo "::error::'${BIN_MOUNT_POINT}' not mounted!" >&2
    exit 1
  fi
}

if [ -z "${OPENWRT_DIR}" -o -z "${OPENWRT_WORK_DIR}" -o -z "${OPENWRT_SOURCE_RECONS_DIR}" ]; then
  echo "::error::'OPENWRT_DIR', 'OPENWRT_WORK_DIR' or 'OPENWRT_SOURCE_RECONS_DIR' is empty" >&2
  exit 1
fi

if [ -z "${REPO_URL}" -o -z "${REPO_BRANCH}" ]; then
  echo "::error::'REPO_URL' or 'REPO_BRANCH' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_DIR}" || true
  link_bin
  exit 0
fi

# The following will reset all non-building changes,
# including some not managed by git, preseve timestamps
# of unchanged files (even if their timestamp changed)
# and make changed files' timestamps most recent

if [ "x${OPENWRT_WORK_DIR}" != "x${OPENWRT_DIR}" -a -d "${OPENWRT_DIR}/.git" -a "x${OPT_UPDATE_REPO}" != "x1" ]; then
  git clone "${OPENWRT_DIR}" "${OPENWRT_WORK_DIR}"
  git -C "${OPENWRT_WORK_DIR}" remote set-url origin "${REPO_URL}"
  git -C "${OPENWRT_WORK_DIR}" fetch
  git -C "${OPENWRT_WORK_DIR}" checkout "${REPO_BRANCH}"
else
  git clone -b "${REPO_BRANCH}" "${REPO_URL}" "${OPENWRT_WORK_DIR}"
fi

link_bin
