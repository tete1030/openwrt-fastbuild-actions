#!/bin/bash

echo "Fallback to single thread compile"
cd openwrt
make -j1 V=s
