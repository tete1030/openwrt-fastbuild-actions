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

PACKAGE_DIR="package/openwrt-packages"
mkdir -p "${OPENWRT_CUR_DIR}/${PACKAGE_DIR}"

# install_package PACKAGE_DIR GIT_URL [REF] [SUBDIR]
install_package() {
  if (( $# < 2 || $# > 4 )); then
    echo "Wrong arguments. Usage: install_package PACKAGE_DIR GIT_URL [REF] [SUBDIR]" >&2
    exit 1
  fi
  PACKAGE_NAME="${1}"
  PACKAGE_URL="${2}"
  PACKAGE_REF="${3}"
  # Remove leading and trailing slashes
  PACKAGE_SUBDIR="${4}" ; PACKAGE_SUBDIR="${PACKAGE_SUBDIR#/}" ; PACKAGE_SUBDIR="${PACKAGE_SUBDIR%/}"

  PACKAGE_PATH="${PACKAGE_DIR}/${PACKAGE_NAME}"
  full_cur_package_path="${OPENWRT_CUR_DIR}/${PACKAGE_PATH}"
  full_compile_package_path="${OPENWRT_COMPILE_DIR}/${PACKAGE_PATH}"
  if [ -d "${full_cur_package_path}" ]; then
    echo "Duplicated package: ${PACKAGE_NAME}" >&2
    exit 1
  fi

  echo "Installing custom package: $*"
  if [ -z "${PACKAGE_SUBDIR}" ]; then
    # Use previous git to preserve version
    if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" ] && [ -d "${full_compile_package_path}/.git" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
      git clone "${full_compile_package_path}" "${full_cur_package_path}"
      git -C "${full_cur_package_path}" remote set-url origin "${PACKAGE_URL}"
      git -C "${full_cur_package_path}" fetch
    else
      git clone "${PACKAGE_URL}" "${full_cur_package_path}"
    fi

    if [ -n "${PACKAGE_REF}" ]; then
      git -C "${full_cur_package_path}" checkout "${PACKAGE_REF}"
    fi
  else
    echo "Using subdir strategy"
    # when using SUBDIR
    # Use previous git to preserve version
    if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" ] && [ -d "${full_compile_package_path}/.git" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
      git clone "${full_compile_package_path}" "${full_cur_package_path}"
    else
      TMP_REPO="${BUILDER_TMP_DIR}/clonesubdir/${PACKAGE_NAME}"
      rm -rf "${TMP_REPO}" || true
      mkdir -p "$(dirname "${TMP_REPO}")" || true
      git clone "${PACKAGE_URL}" "${TMP_REPO}"
      if [ -n "${PACKAGE_REF}" ]; then
        git -C "${TMP_REPO}" checkout "${PACKAGE_REF}"
      fi
      mkdir -p "${full_cur_package_path}"
      rsync -aI --exclude=".git" "${TMP_REPO}/${PACKAGE_SUBDIR}/" "${full_cur_package_path}/"
      rm -rf "${TMP_REPO}"
      # Managing subdir by git to preserve version
      git -C "${full_cur_package_path}" init
      git -C "${full_cur_package_path}" add .
      git -C "${full_cur_package_path}" -c user.name='OFA' -c user.email='builder@ofa' commit -m "Initial commit for ${PACKAGE_NAME}" -m "install_package $*"
    fi
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
