#!/bin/bash

HOST_WORK_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
SCRIPT_DIR="${HOST_WORK_DIR}/scripts"

set -eo pipefail

start_step="$1"
if [[ -z "${start_step}" ]]; then
    start_step=1
fi

if [[ ${start_step} -gt 1 ]]; then
    NO_RESET_ENV=1
fi

export GITHUB_ENV="${HOST_WORK_DIR}/.my-github-env"
if [[ "${NO_RESET_ENV}" != "1" ]]; then
    if [ -f ${GITHUB_ENV} ]; then
        rm -f ${GITHUB_ENV}
    fi
    touch ${GITHUB_ENV}
fi

export LOCAL_RUN=1
export HOST_WORK_DIR
export BUILD_MODE=normal
export BUILD_TARGET=x86_64
export OPT_REBUILD=1
export EXTERNAL_BUILD_DIR="${HOST_WORK_DIR}/build"

run_with_env() {
    if [[ $1 -lt ${start_step} ]]; then
        echo "======================"
        echo "Skipping $2"
        echo "======================"
        return
    fi
    source ${GITHUB_ENV}
    echo "======================"
    echo "Running $2"
    echo "======================"
    $2
}

run_with_env  1 ${SCRIPT_DIR}/cisteps/build-openwrt/01-init_env.sh
run_with_env  2 ${SCRIPT_DIR}/cisteps/build-openwrt/02-check_target.sh
run_with_env  3 ${SCRIPT_DIR}/cisteps/build-openwrt/03-clean_up.sh
run_with_env  4 ${SCRIPT_DIR}/cisteps/build-openwrt/04-configure_docker.sh
run_with_env  5 ${SCRIPT_DIR}/cisteps/build-openwrt/05-check_builders.sh
run_with_env  6 ${SCRIPT_DIR}/cisteps/build-openwrt/06-get_builder.sh
run_with_env  7 ${SCRIPT_DIR}/cisteps/build-openwrt/07-download_openwrt.sh
run_with_env  8 ${SCRIPT_DIR}/cisteps/build-openwrt/08-customize.sh
run_with_env  9 ${SCRIPT_DIR}/cisteps/build-openwrt/09-prepare_config.sh
run_with_env 10 ${SCRIPT_DIR}/cisteps/build-openwrt/10-download_packages.sh
set +eo pipefail
run_with_env 11 ${SCRIPT_DIR}/cisteps/build-openwrt/11-compile_multi.sh
if [[ $? -ne 0 ]]; then
    run_with_env 12 ${SCRIPT_DIR}/cisteps/build-openwrt/12-compile_single.sh
fi
set -eo pipefail
# run_with_env 13 ${SCRIPT_DIR}/cisteps/build-openwrt/13-upload_builder.sh
run_with_env 14 ${SCRIPT_DIR}/cisteps/build-openwrt/14-organize_files.sh

