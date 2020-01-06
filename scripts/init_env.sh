#!/bin/bash

OPENWRT_DIR="openwrt"
OPENWRT_WORK_DIR="${OPENWRT_DIR}"

if [ -d "${OPENWRT_DIR}" ]; then
  OPENWRT_WORK_DIR="${OPENWRT_DIR}_new"
  if [ -d "${OPENWRT_WORK_DIR}" ]; then
    # probably caused by a failure builder upload
    rm -rf "${OPENWRT_WORK_DIR}"
  fi
fi

echo "::set-env name=OPENWRT_DIR::${OPENWRT_DIR}"
echo "::set-env name=OPENWRT_WORK_DIR::${OPENWRT_WORK_DIR}"
