#!/bin/bash

set -eo pipefail

echo "Fallback to single thread compile $COMPILE_OPTIONS"
cd openwrt
make $COMPILE_OPTIONS -j1 V=s
