#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

FROM ubuntu:18.04 AS init-env-stage
RUN useradd -ms /bin/bash builder \
  && apt-get -qq update && apt-get -qq install sudo \
  && /bin/bash -c 'echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99_sudo_include_file'
USER builder
WORKDIR /home/builder
COPY --chown=builder:builder scripts ./scripts
# RUN scripts/initenv.sh
ARG BUILD_TARGET
COPY --chown=builder:builder "user/${BUILD_TARGET}" ./user

FROM init-env-stage AS clone-stage
ARG REPO_URL
ARG REPO_BRANCH
# RUN REPO_URL="${REPO_URL}" REPO_BRANCH="${REPO_BRANCH}" scripts/update_repo.sh
# RUN OPT_UPDATE_FEEDS=1 scripts/update_feeds.sh

FROM clone-stage AS custom-stage
ARG CONFIG_FILE
COPY --chown=builder:builder "${CONFIG_FILE}" ./user/config.diff
# RUN scripts/customize.sh

FROM custom-stage AS download-stage
# RUN scripts/download.sh

FROM download-stage AS compile-stage
# RUN scripts/compile.sh m || scripts/compile.sh s
RUN mkdir -p openwrt/bin/targets/x86/64/packages
RUN echo "Test Firmwares" > openwrt/bin/targets/x86/64/firmware.bin

