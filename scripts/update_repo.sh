#!/bin/bash

set -eo pipefail

if [ -d openwrt ]; then
  git pull --ff
else
  git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt
fi
