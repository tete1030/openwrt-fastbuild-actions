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
COPY --chown=builder:builder scripts ./scripts
RUN scripts/initenv.sh

FROM init-env AS clone
ARG REPO_URL
ARG REPO_BRANCH
RUN REPO_URL="${REPO_URL}" REPO_BRANCH="${REPO_BRANCH}" scripts/update_repo.sh
RUN UPDATE_FEEDS=1 scripts/update_feeds.sh

FROM clone AS custom
ARG CONFIG_FILE
COPY --chown=builder:builder patches ./patches
COPY --chown=builder:builder ${CONFIG_FILE} ./
RUN CONFIG_FILE="${CONFIG_FILE}" scripts/customize.sh

FROM custom AS download
RUN scripts/download.sh

FROM download AS mcompile
RUN COMPILE_OPTIONS="tools/compile" scripts/compile.sh m
RUN COMPILE_OPTIONS="toolchain/compile" scripts/compile.sh m
RUN COMPILE_OPTIONS="prepare" scripts/compile.sh m
RUN COMPILE_OPTIONS="target/compile" scripts/compile.sh m
RUN COMPILE_OPTIONS="package/compile" scripts/compile.sh m
RUN scripts/compile.sh m

FROM download AS scompile
RUN COMPILE_OPTIONS="tools/compile" scripts/compile.sh s
RUN COMPILE_OPTIONS="toolchain/compile" scripts/compile.sh s
RUN COMPILE_OPTIONS="prepare" scripts/compile.sh s
RUN COMPILE_OPTIONS="target/compile" scripts/compile.sh s
RUN COMPILE_OPTIONS="package/compile" scripts/compile.sh s
RUN scripts/compile.sh s
