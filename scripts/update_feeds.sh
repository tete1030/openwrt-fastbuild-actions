#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

echo "Updating and installing feeds ..."
# priority when update_feeds=false: prev > user > legacy (> default)
# priority when update_feeds=true:  user > legacy (> default), no prev

if [ -f "${BUILDER_PROFILE_DIR}/files/feeds.conf" ]; then
  cp "${BUILDER_PROFILE_DIR}/files/feeds.conf" "${OPENWRT_CUR_DIR}/feeds.conf"
fi

# Backup feeds.conf file
if [ -f "${OPENWRT_CUR_DIR}/feeds.conf" ]; then
  cp "${OPENWRT_CUR_DIR}/feeds.conf" "${BUILDER_TMP_DIR}/feeds.conf.bak"
fi

if [ "x${OPENWRT_CUR_DIR}" != "x${OPENWRT_COMPILE_DIR}" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
  # Use previous feeds
  (
    set +eo pipefail
    # Use previous feeds status
    cd "${OPENWRT_COMPILE_DIR}" && ./scripts/feeds list -fs > "${BUILDER_TMP_DIR}/feeds.conf.prev"
  )
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    echo "::warning::Something went wrong in previous builder. Not using last feeds.conf"
    rm "${BUILDER_TMP_DIR}/feeds.conf.prev" || true
  else
    mv "${BUILDER_TMP_DIR}/feeds.conf.prev" "${OPENWRT_CUR_DIR}/feeds.conf"
  fi
fi

(
  cd "${OPENWRT_CUR_DIR}"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
)

if [ -f "${BUILDER_TMP_DIR}/feeds.conf.bak" ]; then
  mv "${BUILDER_TMP_DIR}/feeds.conf.bak" "${OPENWRT_CUR_DIR}/feeds.conf" 
fi

PACKAGE_DEFAULT_ROOT="package/openwrt-packages"

# install_package PACKAGE_NAME GIT_URL [ref=REF] [root=ROOT] [subdir=SUBDIR] [rename=RENAME] [mkfile-dir=MKFILE_DIR] [use-latest-tag] [override]
# REF is optional. You can specify branch/tag/commit
# ROOT is optional. Specifying the parent path of your package. Defaults to 'package/openwrt-packages'.
# SUBDIR is optional. The path of subdir within the repo can be specified
# RENAME is optional. It allows renaming of PKG_NAME in Makefile of the package
# MKFILE_DIR is optional. You can specify the dir of Makefile, only used when RENAME is specified.
# 'use-latest-tag' will retrieve latest release as the REF. It shouldn't be specified together with REF. Currently only github repo is supported.
# 'override' will delete packages that are already existed.
#
# Examples:
# mentohust https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk.git
# luci-app-mentohust https://github.com/BoringCat/luci-app-mentohust.git ref=1db86057
# syslog-ng-latest https://github.com/openwrt/packages.git ref=master subdir=admin/syslog-ng rename=syslog-ng-latest
install_package() {
  if (( $# < 2 )); then
    echo "install_package: wrong arguments. Usage: install_package PACKAGE_NAME GIT_URL [ref=REF] [root=ROOT] [subdir=SUBDIR] [rename=RENAME] [mkfile-dir=MKFILE_DIR] [use-latest-tag] [override]" >&2
    exit 1
  fi
  local ALL_PARAMS="$*"
  local PACKAGE_NAME="${1}"; shift;
  local PACKAGE_URL="${1}"; shift;
  local PACKAGE_REF=""
  local PACKAGE_ROOT="${PACKAGE_DEFAULT_ROOT}"
  local PACKAGE_SUBDIR=""
  local PACKAGE_RENAME=""
  local PACKAGE_MKFILE_DIR=""
  local USE_LATEST_TAG=0
  local OVERRIDE=0

  for para in "$@"; do
    case "$para" in
      ref=*) PACKAGE_REF="${para#ref=}" ;;
      root=*)
        PACKAGE_ROOT="${para#root=}"
        PACKAGE_ROOT="${PACKAGE_ROOT##/}"
        PACKAGE_ROOT="${PACKAGE_ROOT%%/}"
        PACKAGE_ROOT="package/${PACKAGE_ROOT}"
        ;;
      subdir=*)
        PACKAGE_SUBDIR="${para#subdir=}"
        # Remove leading and trailing slashes
        PACKAGE_SUBDIR="${PACKAGE_SUBDIR##/}"
        PACKAGE_SUBDIR="${PACKAGE_SUBDIR%%/}"
        ;;
      rename=*) PACKAGE_RENAME="${para#rename=}" ;;
      mkfile-dir=*)
        PACKAGE_MKFILE_DIR="${para#mkfile-dir=}"
        PACKAGE_MKFILE_DIR="${PACKAGE_MKFILE_DIR##/}"
        PACKAGE_MKFILE_DIR="${PACKAGE_MKFILE_DIR%%/}"
        ;;
      use-latest-tag) USE_LATEST_TAG=1 ;;
      override) OVERRIDE=1 ;;
      *)
        echo "install_package: unknown parameter for install_package: $para" >&2
        exit 1
        ;;
    esac
  done

  if [ ${USE_LATEST_TAG} -eq 1 ]; then
    if [ -n "${PACKAGE_REF}" ]; then
      echo "install_package: 'use-latest-tag' should not be used together with 'ref'" >&2
      exit 1
    fi
    local repo_name=""
    if [[ "${PACKAGE_URL}" =~ ^https?://github\.com/.*$ ]]; then
      repo_name="$(perl -lne '/^https?:\/\/github\.com\/(.+?)\/(.+?)(?:\.git)?(?:\/.*)?$/ && print "$1/$2"' <<<"${PACKAGE_URL}")"
    elif [[ "${PACKAGE_URL}" =~ ^git@github.com/.*$ ]]; then
      repo_name="$(perl -lne '/^git\@github\.com:(.+?)\/(.+?)(?:\.git)?$/ && print "$1/$2"' <<<"${PACKAGE_URL}")"
    fi
    if [ -z "${repo_name}" ]; then
      echo "install_package: unknown PACKAGE_URL for retrieving latest tag: ${PACKAGE_URL}" >&2
      exit 1
    fi
    # We use /tags instead /releases because the /releases api is not consistent with its webpage, which lists all tags
    local latest_tag
    latest_tag="$(set +eo pipefail; curl -sL --connect-timeout 10 --retry 5 "https://api.github.com/repos/${repo_name}/tags" 2>/dev/null | grep '"name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1; true)"
    if [ -z "${latest_tag}" ]; then
      echo "install_package: no latest tag found" >&2
      exit 1
    fi
    echo "install_package: latest tag is ${latest_tag}"
    PACKAGE_REF="${latest_tag}"
  fi

  [ -d "${OPENWRT_CUR_DIR}/${PACKAGE_ROOT}" ] || mkdir -p "${OPENWRT_CUR_DIR}/${PACKAGE_ROOT}"

  local package_path="${PACKAGE_ROOT}/${PACKAGE_NAME}"
  local full_cur_package_path="${OPENWRT_CUR_DIR}/${package_path}"
  local full_compile_package_path="${OPENWRT_COMPILE_DIR}/${package_path}"

  if [ -d "${full_cur_package_path}" ]; then
    if [ $OVERRIDE -eq 1 ]; then
      echo "install_package: removing existed package: ${package_path}"
      rm -rf "${full_cur_package_path}"
    else
      echo "install_package: package already exists: ${package_path}" >&2
      exit 1
    fi
  fi

  echo "install_package: installing custom package: ${ALL_PARAMS}"
  if [ -z "${PACKAGE_SUBDIR}" ]; then
    # Use previous git to preserve version
    if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" ] && [ -d "${full_compile_package_path}/.git" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
      git clone "${full_compile_package_path}" "${full_cur_package_path}"
      git -C "${full_cur_package_path}" remote set-url origin "${PACKAGE_URL}"
      git -C "${full_cur_package_path}" fetch
      if [ -n "${PACKAGE_REF}" ]; then
        echo "install_package: PACKAGE_REF is not respected as 'update_feeds' is not enabled"
      fi
    else
      git clone "${PACKAGE_URL}" "${full_cur_package_path}"
      if [ -n "${PACKAGE_REF}" ]; then
        git -C "${full_cur_package_path}" checkout "${PACKAGE_REF}"
      fi
    fi
  else
    echo "install_package: using subdir strategy"
    # when using SUBDIR
    # Use previous git to preserve version
    if [ "x${full_cur_package_path}" != "x${full_compile_package_path}" ] && [ -d "${full_compile_package_path}/.git" ] && [ "x${OPT_UPDATE_FEEDS}" != "x1" ]; then
      git clone "${full_compile_package_path}" "${full_cur_package_path}"
      if [ -n "${PACKAGE_REF}" ]; then
        echo "install_package: PACKAGE_REF is not respected as 'update_feeds' is not enabled"
      fi
    else
      local TMP_REPO="${BUILDER_TMP_DIR}/clonesubdir/${PACKAGE_NAME}"
      rm -rf "${TMP_REPO}" || true
      mkdir -p "$(dirname "${TMP_REPO}")" || true
      git clone "${PACKAGE_URL}" "${TMP_REPO}"
      if [ -n "${PACKAGE_REF}" ]; then
        git -C "${TMP_REPO}" checkout "${PACKAGE_REF}"
      fi
      mkdir -p "${full_cur_package_path}"
      rsync -aI --exclude=".git" "${TMP_REPO}/${PACKAGE_SUBDIR}/" "${full_cur_package_path}/"
      rm -rf "${TMP_REPO}"
      # Managing subdir by git to preserve version
      git -C "${full_cur_package_path}" init
      git -C "${full_cur_package_path}" add .
      git -C "${full_cur_package_path}" -c user.name='OFA' -c user.email='builder@ofa' commit -m "Initial commit for ${PACKAGE_NAME}" -m "install_package ${ALL_PARAMS}"
    fi
  fi

  # rename PKG_NAME in Makefile
  if [ -n "${PACKAGE_RENAME}" ]; then
    local package_mkfile="Makefile"
    if [ -n "${PACKAGE_MKFILE_DIR}" ]; then
      package_mkfile="${PACKAGE_MKFILE_DIR}/${package_mkfile}"
    fi
    package_mkfile="${full_cur_package_path}/${package_mkfile}"
    echo "install_package: renaming PKG_NAME to ${PACKAGE_RENAME} in ${package_mkfile}"
    if [ ! -f "${package_mkfile}" ]; then
      echo "install_package: ${package_mkfile} not found" >&2
      exit 1
    fi
    local package_rename_escaped
    package_rename_escaped="$(sed 's/[\/&]/\\&/g' <<<"${PACKAGE_RENAME}")"
    sed -i 's/^PKG_NAME:\?=.*$/PKG_NAME:='"${package_rename_escaped}"'/' "${package_mkfile}"
  fi
}

if [ -f "${BUILDER_PROFILE_DIR}/packages.txt" ]; then
  while IFS= read -r line; do
    if [ -n "${line// }" ] && [[ ! "${line}" =~ ^[[:blank:]]*\# ]] ; then
      # 'eval' can help evaluate parameter quotes
      eval "install_package ${line}"
    fi
  done <"${BUILDER_PROFILE_DIR}/packages.txt"
fi
