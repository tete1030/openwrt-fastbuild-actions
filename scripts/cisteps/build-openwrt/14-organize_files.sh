#!/bin/bash

set -eo pipefail

shopt -s extglob

sudo chown -R "$(id -u):$(id -g)" "${HOST_BIN_DIR}"
if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
  mkdir "${HOST_WORK_DIR}/openwrt_firmware"
  # shellcheck disable=SC2164
  cd "${HOST_BIN_DIR}/targets/"*/*
  all_firmware_files=( !(packages) )
  # shellcheck disable=SC2015
  [ ${#all_firmware_files[@]} -gt 0 ] && mv "${all_firmware_files[@]}" "${HOST_WORK_DIR}/openwrt_firmware/" || true
fi
echo "::set-output name=status::success"
