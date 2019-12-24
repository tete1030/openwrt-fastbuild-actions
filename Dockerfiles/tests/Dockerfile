#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

FROM ubuntu:18.04 AS init-env
RUN useradd -ms /bin/bash builder \
  && apt-get -qq update && apt-get -qq install sudo \
  && /bin/bash -c 'echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99_sudo_include_file'
USER builder
WORKDIR /home/builder
RUN mkdir scripts
COPY --chown=builder:builder scripts/initenv.sh ./scripts/initenv.sh
# RUN scripts/initenv.sh

FROM init-env AS clone
ARG REPO_URL
ARG REPO_BRANCH
COPY --chown=builder:builder scripts/update_repo.sh ./scripts/update_repo.sh
COPY --chown=builder:builder scripts/update_feeds.sh ./scripts/update_feeds.sh
# RUN REPO_URL="${REPO_URL}" REPO_BRANCH="${REPO_BRANCH}" scripts/update_repo.sh
# RUN UPDATE_FEEDS=1 scripts/update_feeds.sh
RUN mkdir openwrt

FROM clone AS custom
ARG CONFIG_FILE
COPY --chown=builder:builder scripts/customize.sh ./scripts/customize.sh
COPY --chown=builder:builder patches ./patches
COPY --chown=builder:builder ${CONFIG_FILE} ./
# RUN CONFIG_FILE="${CONFIG_FILE}" scripts/customize.sh

FROM custom AS download
COPY --chown=builder:builder scripts/download.sh ./scripts/download.sh
# RUN scripts/download.sh

FROM download AS compile
COPY --chown=builder:builder scripts/compile.sh ./scripts/compile.sh
# RUN COMPILE_OPTIONS="prepare" scripts/compile.sh m \
#   || COMPILE_OPTIONS="prepare" scripts/compile.sh s
# RUN scripts/compile.sh m || scripts/compile.sh s

RUN mkdir -p openwrt/bin/targets/x86/64/packages
RUN echo "Test Firmwares" > openwrt/bin/targets/x86/64/firmware.bin

