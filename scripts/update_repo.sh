#!/bin/bash

set -eo pipefail

if [ -d openwrt ]; then
  git pull --ff
else
  if [ -z "${REPO_URL}" -o -z "${REPO_BRANCH}" ]; then
    echo "'REPO_URL' or 'REPO_BRANCH' is empty" >&2
    exit 1
  fi
  git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt
fi
