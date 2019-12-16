#!/bin/bash

set -eo pipefail

cd openwrt
echo -e "$(nproc) thread compile"
make -j$(nproc)
