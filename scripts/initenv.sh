#!/bin/bash

set -eo pipefail

echo "Installing building components ..."
sudo -E apt-get -qq update
sudo -E apt-get -qq install build-essential asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler
sudo -E apt-get -qq install tar wget curl nginx
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
curl -fsSL https://raw.githubusercontent.com/P3TERX/dotfiles/master/.bashrc >> ~/.bashrc
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
