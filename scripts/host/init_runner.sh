#!/bin/bash
# shellcheck disable=SC2034

set -eo pipefail

echo "Installing necessary commands..."
export DEBIAN_FRONTEND=noninteractive

sudo -E apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
sudo -E add-apt-repository -y ppa:rmescandon/yq
sudo -E apt-get -qq update && sudo -E apt-get -qq install jq yq tree

# shellcheck source=scripts/host/utils.sh disable=SC1091
source "${GITHUB_WORKSPACE}/scripts/host/utils.sh"

# Fixed parameters, do not change the following values
DK_BUILDX_DRIVER=docker
# DK_CONTEXT=.
# DK_NO_REMOTE_CACHE=1
# DK_NO_BUILDTIME_PUSH=1
# DK_CONVERT_MULTISTAGE_TO_IMAGE=1
# DK_BUILD_ARGS='REPO_URL REPO_BRANCH DK_IMAGE_BASE OPT_UPDATE_REPO OPT_UPDATE_FEEDS OPT_PACKAGE_ONLY'
BUILDER_IMAGE_ID_BUILDENV="tete1030/openwrt-buildenv:latest"
BUILDER_CONTAINER_ID="builder"
BUILDER_HOME_DIR="/home/builder"
BUILDER_TMP_DIR="/tmp/builder"
BUILDER_TMP_DIR_HOST="/tmp/builder"
BUILDER_PROFILE_DIR="${BUILDER_HOME_DIR}/user/current"
BUILDER_MOUNT_OPTS="
  -v '${GITHUB_WORKSPACE}/scripts:${BUILDER_HOME_DIR}/scripts'
  -v '${GITHUB_WORKSPACE}/user:${BUILDER_HOME_DIR}/user'
  -v '${GITHUB_WORKSPACE}/openwrt_bin:${BUILDER_HOME_DIR}/openwrt_bin'
  -v '${BUILDER_TMP_DIR_HOST}:${BUILDER_TMP_DIR}'
"
_set_env_prefix DK_
_set_env BUILDER_IMAGE_ID_BUILDENV BUILDER_CONTAINER_ID BUILDER_HOME_DIR BUILDER_TMP_DIR BUILDER_PROFILE_DIR BUILDER_MOUNT_OPTS
_append_docker_exec_env TEST OPENWRT_CUR_DIR OPENWRT_COMPILE_DIR OPENWRT_SOURCE_DIR BUILDER_HOME_DIR BUILDER_TMP_DIR BUILDER_PROFILE_DIR

# Set for target
BUILD_TARGET="$(echo "${MATRIX_CONTEXT}" | jq -crMe ".target")"
if [ ! -d "${GITHUB_WORKSPACE}/user/${BUILD_TARGET}" ]; then
  echo "::error::Failed to find target ${BUILD_TARGET}" >&2
  exit 1
fi
_set_env BUILD_TARGET

# Load default and target configs
if [ -d "${GITHUB_WORKSPACE}/user/default" ]; then
  cp -r "${GITHUB_WORKSPACE}/user/default" "${GITHUB_WORKSPACE}/user/current"
else
  mkdir "${GITHUB_WORKSPACE}/user/current"
fi
rsync -aI "${GITHUB_WORKSPACE}/user/${BUILD_TARGET}/" "${GITHUB_WORKSPACE}/user/current/"
echo "Merged target profile structure:"
tree "${GITHUB_WORKSPACE}/user/current"

if [ ! -f "${GITHUB_WORKSPACE}/user/current/config.diff" ]; then
  echo "::error::Config file 'config.diff' does not exist" >&2
  exit 1
fi

# Load settings
NECESSARY_SETTING_VARS=( BUILDER_NAME BUILDER_TAG REPO_URL REPO_BRANCH )
OPT_UPLOAD_CONFIG='1'
SETTING_VARS=( "${NECESSARY_SETTING_VARS[@]}" OPT_UPLOAD_CONFIG )
[ ! -f "${GITHUB_WORKSPACE}/user/default/settings.ini" ] || _source_vars "${GITHUB_WORKSPACE}/user/default/settings.ini" "${SETTING_VARS[@]}"
_source_vars "${GITHUB_WORKSPACE}/user/current/settings.ini" "${SETTING_VARS[@]}"
setting_missing_vars="$(_check_missing_vars "${NECESSARY_SETTING_VARS[@]}")"
if [ -n "${setting_missing_vars}" ]; then
  echo "::error::Variables missing in 'user/default/settings.ini' and 'user/${BUILD_TARGET}/settings.ini': ${setting_missing_vars}"
  exit 1
fi
_set_env "${SETTING_VARS[@]}"
_append_docker_exec_env "${SETTING_VARS[@]}"

# Prepare for test
if [ "x$(echo "${MATRIX_CONTEXT}" | jq -crMe ".mode")" = "xtest" ]; then
  BUILDER_TAG="test-${BUILDER_TAG}"
  TEST=1
  _set_env BUILDER_TAG TEST
fi

BUILDER_NAME="${DK_USERNAME}/${BUILDER_NAME}"
BUILDER_TAG_INC="${BUILDER_TAG}-inc"
BUILDER_IMAGE_ID_BASE="${DK_REGISTRY:+$DK_REGISTRY/}${BUILDER_NAME}:${BUILDER_TAG}"
BUILDER_IMAGE_ID_INC="${DK_REGISTRY:+$DK_REGISTRY/}${BUILDER_NAME}:${BUILDER_TAG_INC}"
_set_env BUILDER_IMAGE_ID_BASE BUILDER_IMAGE_ID_INC

# Load building action
if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
  RD_TASK=""
  _COMMIT_MESSAGE="$(jq -crMe ".event.head_commit.message" <<<"${GITHUB_CONTEXT}")"
  RD_TARGET="$(_extract_opt_from_string "target" "${_COMMIT_MESSAGE}" "")"
elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ]; then
  RD_TASK="$(jq -crM '.event.action // ""' <<<"${GITHUB_CONTEXT}")"
  RD_TARGET="$(jq -crM '.event.client_payload.target // ""' <<<"${GITHUB_CONTEXT}")"
elif [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
  RD_TASK="$(jq -crM '.event.deployment.task // ""' <<<"${GITHUB_CONTEXT}")"
  RD_TARGET="$(jq -crM '.event.deployment.payload.target // ""' <<<"${GITHUB_CONTEXT}")"
fi
_set_env RD_TASK RD_TARGET

# Load building options
(
  IFS=$'\x20'
  for opt_name in ${BUILD_OPTS}; do
    _load_opt "${opt_name}"
  done
)

if [ "x${OPT_DEBUG}" = "x1" ] && [ -z "${TMATE_ENCRYPT_PASSWORD}" ] && [ -z "${SLACK_WEBHOOK_URL}" ]; then
  echo "::error::To use debug mode, you should set either TMATE_ENCRYPT_PASSWORD or SLACK_WEBHOOK_URL in the 'Secrets' page for safety of your sensitive information. For details, please refer to https://git.io/JvfLS"
  echo "::error::In the reference URL you are instructed to use environment variables for them. However in this repo, you should set them in the 'Secrets' page"
  exit 1
fi

mkdir -p "${GITHUB_WORKSPACE}/openwrt_bin"
chmod 777 "${GITHUB_WORKSPACE}/openwrt_bin"
sudo mkdir "${BUILDER_TMP_DIR_HOST}"
sudo chmod 777 "${BUILDER_TMP_DIR_HOST}"
