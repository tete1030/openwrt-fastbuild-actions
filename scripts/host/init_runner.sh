#!/bin/bash
# shellcheck disable=SC2034

install_commands() {
  echo "Installing necessary commands..."
  export DEBIAN_FRONTEND=noninteractive

  sudo -E apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
  sudo -E add-apt-repository -y ppa:rmescandon/yq
  sudo -E apt-get -qq update && sudo -E apt-get -qq install jq yq tree
}

setup_envs() {
  # Do not change
  BUILDER_IMAGE_ID_BUILDENV="tete1030/openwrt-buildenv:latest"
  BUILDER_CONTAINER_ID="builder"
  BUILDER_WORK_DIR="/home/builder"
  BUILDER_TMP_DIR="/tmp/builder"
  HOST_TMP_DIR="/tmp/builder"
  BUILDER_BIN_DIR="${BUILDER_WORK_DIR}/openwrt_bin"
  HOST_BIN_DIR="${HOST_WORK_DIR}/openwrt_bin"
  BUILDER_PROFILE_DIR="${BUILDER_WORK_DIR}/user/current"
  BUILDER_MOUNT_OPTS="
    -v '${HOST_WORK_DIR}/scripts:${BUILDER_WORK_DIR}/scripts'
    -v '${HOST_WORK_DIR}/user:${BUILDER_WORK_DIR}/user'
    -v '${HOST_BIN_DIR}:${BUILDER_BIN_DIR}'
    -v '${HOST_TMP_DIR}:${BUILDER_TMP_DIR}'
  "
  OPENWRT_COMPILE_DIR="${BUILDER_WORK_DIR}/openwrt"
  OPENWRT_SOURCE_DIR="${BUILDER_TMP_DIR}/openwrt"
  OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"

  # shellcheck disable=SC1090
  source "${HOST_WORK_DIR}/scripts/host/docker.sh"
  # shellcheck disable=SC1090
  source "${HOST_WORK_DIR}/scripts/lib/gaction.sh"
  # shellcheck disable=SC1090
  source "${HOST_WORK_DIR}/scripts/lib/utils.sh"

  _set_env HOST_TMP_DIR HOST_BIN_DIR
  _set_env BUILDER_IMAGE_ID_BUILDENV BUILDER_CONTAINER_ID BUILDER_WORK_DIR BUILDER_TMP_DIR BUILDER_BIN_DIR BUILDER_PROFILE_DIR BUILDER_MOUNT_OPTS
  append_docker_exec_env BUILDER_WORK_DIR BUILDER_TMP_DIR BUILDER_BIN_DIR BUILDER_PROFILE_DIR
  _set_env DK_EXEC_ENVS

  _set_env OPENWRT_COMPILE_DIR OPENWRT_SOURCE_DIR OPENWRT_CUR_DIR
  append_docker_exec_env OPENWRT_COMPILE_DIR OPENWRT_SOURCE_DIR OPENWRT_CUR_DIR
  _set_env DK_EXEC_ENVS
}

check_test() {
  # Prepare for test
  if [ "x${BUILD_MODE}" = "xtest" ]; then
    TEST=1
    _set_env TEST
    append_docker_exec_env TEST
    _set_env DK_EXEC_ENVS
  fi
}

load_task() {
  # Load building action
  if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
    RD_TASK=""
    local commit_message
    commit_message="$(jq -crMe ".head_commit.message" "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(_extract_opt_from_string "target" "${commit_message}" "" "")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ]; then
    RD_TASK="$(jq -crM '.action // ""' "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(jq -crM '.client_payload.target // ""' "${GITHUB_EVENT_PATH}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
    RD_TASK="$(jq -crM '.deployment.task // ""' "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(jq -crM '.deployment.payload.target // ""' "${GITHUB_EVENT_PATH}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xworkflow_dispatch" ]; then
    RD_TASK=""
    RD_TARGET="$(jq -crM '.inputs.target // ""' "${GITHUB_EVENT_PATH}")"
  fi
  _set_env RD_TASK RD_TARGET
}

prepare_target() {
  # Set for target
  if [ ! -d "${HOST_WORK_DIR}/user/${BUILD_TARGET}" ]; then
    echo "::error::Failed to find target ${BUILD_TARGET}" >&2
    exit 1
  fi

  # Load default and target configs
  if [ -d "${HOST_WORK_DIR}/user/default" ]; then
    cp -r "${HOST_WORK_DIR}/user/default" "${HOST_WORK_DIR}/user/current"
  else
    mkdir "${HOST_WORK_DIR}/user/current"
  fi
  rsync -aI "${HOST_WORK_DIR}/user/${BUILD_TARGET}/" "${HOST_WORK_DIR}/user/current/"
  echo "Merged target profile structure:"
  tree "${HOST_WORK_DIR}/user/current"

  if [ ! -f "${HOST_WORK_DIR}/user/current/config.diff" ]; then
    echo "::error::Config file 'config.diff' does not exist" >&2
    exit 1
  fi

  # Load settings
  NECESSARY_SETTING_VARS=( BUILDER_NAME BUILDER_TAG REPO_URL REPO_BRANCH )
  OPT_UPLOAD_CONFIG='1'
  SETTING_VARS=( "${NECESSARY_SETTING_VARS[@]}" OPT_UPLOAD_CONFIG )
  [ ! -f "${HOST_WORK_DIR}/user/default/settings.ini" ] || _source_vars "${HOST_WORK_DIR}/user/default/settings.ini" "${SETTING_VARS[@]}"
  _source_vars "${HOST_WORK_DIR}/user/current/settings.ini" "${SETTING_VARS[@]}"
  setting_missing_vars="$(_check_missing_vars "${NECESSARY_SETTING_VARS[@]}")"
  if [ -n "${setting_missing_vars}" ]; then
    echo "::error::Variables missing in 'user/default/settings.ini' and 'user/${BUILD_TARGET}/settings.ini': ${setting_missing_vars}"
    exit 1
  fi
  _set_env "${SETTING_VARS[@]}"
  append_docker_exec_env "${SETTING_VARS[@]}"
  _set_env DK_EXEC_ENVS
}

# Load building options
load_options() {
  __set_env_and_docker_exec() {
    _set_env "${1}"
    append_docker_exec_env "${1}"
  }
  for opt_name in ${BUILD_OPTS}; do
    _load_opt "${opt_name}" "" __set_env_and_docker_exec
  done
  _set_env DK_EXEC_ENVS
}

update_builder_info() {
  if [ "x${TEST}" = "x1" ]; then
    BUILDER_TAG="test-${BUILDER_TAG}"
    _set_env BUILDER_TAG
  fi
  local builder_full_name="${DK_REGISTRY:+$DK_REGISTRY/}${DK_USERNAME}/${BUILDER_NAME}"
  BUILDER_TAG_INC="${BUILDER_TAG}-inc"
  BUILDER_IMAGE_ID_BASE="${builder_full_name}:${BUILDER_TAG}"
  BUILDER_IMAGE_ID_INC="${builder_full_name}:${BUILDER_TAG_INC}"
  _set_env BUILDER_IMAGE_ID_BASE BUILDER_IMAGE_ID_INC
}

check_validity() {
  if [ "x${OPT_DEBUG}" = "x1" ] && [ -z "${TMATE_ENCRYPT_PASSWORD}" ] && [ -z "${SLACK_WEBHOOK_URL}" ]; then
    echo "::error::To use debug mode, you should set either TMATE_ENCRYPT_PASSWORD or SLACK_WEBHOOK_URL in the 'Secrets' page for safety of your sensitive information. For details, please refer to https://git.io/JvfLS"
    echo "::error::In the reference URL you are instructed to use environment variables for them. However in this repo, you should set them in the 'Secrets' page"
    exit 1
  fi
}

prepare_dirs() {
  mkdir -p "${HOST_BIN_DIR}"
  chmod 777 "${HOST_BIN_DIR}"
  sudo mkdir "${HOST_TMP_DIR}"
  sudo chmod 777 "${HOST_TMP_DIR}"
}

main() {
  set -eo pipefail
  if [ "$1" = "build" ]; then
    BUILD_OPTS="update_feeds update_repo rebase rebuild debug push_when_fail package_only"
  fi

  install_commands
  setup_envs
  check_test
  load_task
  prepare_target
  load_options
  update_builder_info
  check_validity
  prepare_dirs
}

if [ "x$1" = "xmain" ]; then
  shift
  main "$@"
fi
