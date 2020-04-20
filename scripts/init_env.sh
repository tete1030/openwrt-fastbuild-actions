#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${BUILDER_WORK_DIR}/scripts/lib/gaction.sh"

OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
# if we are not fresh building
if [ -d "${OPENWRT_COMPILE_DIR}" ]; then
  OPENWRT_CUR_DIR="${OPENWRT_SOURCE_DIR}"
  if [ -d "${OPENWRT_CUR_DIR}" ]; then
    # probably caused by a broken builder upload
    rm -rf "${OPENWRT_CUR_DIR}"
  fi
fi

_set_env OPENWRT_CUR_DIR

[ "x${TEST}" != "x1" ] || exit 0

# Install missing packages in current env from a remote list
sudo -E apt-get -qq update
if [ ! -x "$(command -v curl)" ]; then
    echo "curl not found, installing..."
    sudo -E apt-get -qq install curl
fi
packages_file="${BUILDER_TMP_DIR}/packages.txt"
packages_url="https://github.com/tete1030/openwrt-buildenv/raw/master/packages.txt"
(
  set +eo pipefail
  
  rm -f "${packages_file}" || true
  echo "Downloading package list from ${packages_url}"
  curl -sLo "${packages_file}" "${packages_url}"
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    rm -f "${packages_file}" || true
    echo "Downloading package list failed"
  fi
  true
)
if [ -f "${packages_file}" ]; then
  echo "Installing missing packages"
  mapfile -t all_packages < <(grep -vE -e "^\s*#" -e "^\s*\$" "${packages_file}")
  sudo -E apt-get -qq install --no-upgrade "${all_packages[@]}"
  echo "Installed packages: ${all_packages[*]}"
  rm -f "${packages_file}"
fi
