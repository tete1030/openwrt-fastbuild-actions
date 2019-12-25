#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

# Not recommended to change as they are already in optimal condition.
# If you insist to change the content, make sure the corresponding file
# in the 'tests' dir is also changed in the same way.
# 不推荐修改，已处在最优状态。如果仍要修改，确保tests文件夹中的对应文件以类似方式修改。

FROM ubuntu:18.04 AS init-env
RUN useradd -ms /bin/bash builder \
  && apt-get -qq update && apt-get -qq install sudo \
  && /bin/bash -c 'echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99_sudo_include_file'
USER builder
WORKDIR /home/builder
RUN mkdir scripts
# Copying each script separately instead of copying all scripts altogether to maximumlly leverage building cache
COPY --chown=builder:builder scripts/initenv.sh ./scripts/initenv.sh
RUN scripts/initenv.sh

FROM init-env AS clone
ARG REPO_URL
ARG REPO_BRANCH
COPY --chown=builder:builder scripts/update_repo.sh ./scripts/update_repo.sh
RUN REPO_URL="${REPO_URL}" REPO_BRANCH="${REPO_BRANCH}" scripts/update_repo.sh
COPY --chown=builder:builder scripts/update_feeds.sh ./scripts/update_feeds.sh
RUN OPT_UPDATE_FEEDS=1 scripts/update_feeds.sh

FROM clone AS custom
ARG CONFIG_FILE
COPY --chown=builder:builder scripts/customize.sh ./scripts/customize.sh
COPY --chown=builder:builder patches ./patches
COPY --chown=builder:builder ${CONFIG_FILE} ./
RUN CONFIG_FILE="${CONFIG_FILE}" scripts/customize.sh

FROM custom AS download
COPY --chown=builder:builder scripts/download.sh ./scripts/download.sh
RUN scripts/download.sh

FROM download AS compile
COPY --chown=builder:builder scripts/compile.sh ./scripts/compile.sh
RUN COMPILE_OPTIONS="prepare" scripts/compile.sh m \
  || COMPILE_OPTIONS="prepare" scripts/compile.sh s
RUN scripts/compile.sh m || scripts/compile.sh s

