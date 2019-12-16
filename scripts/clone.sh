#!/bin/bash

git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt

echo "Updating and installing feeds ..."
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a
