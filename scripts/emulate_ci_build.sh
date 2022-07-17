#!/bin/bash

HOST_WORK_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
SCRIPT_DIR="${HOST_WORK_DIR}/scripts"

set -eo pipefail

export GITHUB_ENV="${HOST_WORK_DIR}/.my-github-env"
if [ -f ${GITHUB_ENV} ]; then
    rm -f ${GITHUB_ENV}
fi
touch ${GITHUB_ENV}

export LOCAL_RUN=1
export HOST_WORK_DIR
export BUILD_MODE=normal
export BUILD_TARGET=x86_64
export OPT_REBUILD=1

run_with_env() {
    source ${GITHUB_ENV}
    $1
}

run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/01-init_env.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/02-check_target.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/03-clean_up.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/04-configure_docker.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/05-check_builders.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/06-get_builder.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/07-download_openwrt.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/08-customize.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/09-prepare_config.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/10-download_packages.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/11-compile_multi.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/13-upload_builder.sh
run_with_env ${SCRIPT_DIR}/cisteps/build-openwrt/14-upload_builder.sh

