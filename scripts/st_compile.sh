#!/bin/bash

set -eo pipefail

echo "Fallback to single thread compile"
cd openwrt
make -j1 V=s
