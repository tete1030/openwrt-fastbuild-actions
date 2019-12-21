#!/bin/bash

# From https://github.com/P3TERX/Actions-OpenWrt

echo "Deleting files, please wait ..."
sudo rm -rf /usr/share/dotnet /etc/apt/sources.list.d/*
sudo swapoff /swapfile
sudo rm -f /swapfile
#docker rmi `docker images -q`
#sudo -E apt-get -q purge azure-cli ghc* zulu* hhvm llvm* firefox google* dotnet* powershell openjdk* mysql* php*