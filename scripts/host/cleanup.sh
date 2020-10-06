#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set +eo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Deleting files, please wait ..."
sudo rm -rf /opt/hostedtoolcache /usr/share/dotnet /etc/apt/sources.list.d/* /var/cache/apt/archives /usr/local/share/boost /usr/local/go* /usr/local/lib/android /opt/ghc
sudo swapoff /swapfile 2>/dev/null
sudo rm -f /swapfile
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
sudo -E apt-get -q purge azure-cli zulu* hhvm llvm* firefox google* dotnet* powershell openjdk* mysql*
exit 0
