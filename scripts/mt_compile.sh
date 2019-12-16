#!/bin/bash

cd openwrt
echo -e "$(nproc) thread compile"
make -j$(nproc)
