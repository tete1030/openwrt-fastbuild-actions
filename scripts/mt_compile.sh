#!/bin/bash

set -e

cd openwrt
echo -e "$(nproc) thread compile"
make -j$(nproc)
