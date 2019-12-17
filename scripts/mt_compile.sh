#!/bin/bash

set -eo pipefail

cd openwrt
echo -e "$(nproc) thread compile $COMPILE_OPTIONS"
make $COMPILE_OPTIONS -j$(nproc)
