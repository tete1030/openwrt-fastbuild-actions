#!/bin/bash

_set_env() {
    for var_name in $@ ; do
        echo "::set-env name=${var_name}::${!var_name}"
    done
}

_set_env_prefix() {
    for var_name_prefix in $@ ; do
        eval '_set_env ${!'"${var_name_prefix}"'@}'
    done
}

# Not recommended to change unless you understand how it is used
# 以下参数不推荐修改
DK_BUILDX_DRIVER=docker
DK_CONTEXT=.
DK_NO_REMOTE_CACHE=1
DK_NO_BUILDTIME_PUSH=1
DK_CONVERT_MULTISTAGE_TO_IMAGE=1
DOCKERFILE_BASE=Dockerfile
DOCKERFILE_INC=Dockerfile-inc
DOCKERFILE_PACKAGE=Dockerfile-package
CONFIG_FILE_DEFAULT='config.diff.default'
_set_env_prefix DK_ DOCKERFILE_ CONFIG_FILE

BUILDER_NAME="${DK_USERNAME}/${BUILDER_NAME}"
BUILDER_TAG_INC="${BUILDER_TAG}-inc"
BUILDER_TAG_PACKAGE="${BUILDER_TAG}-package"
BUILDER_ID_BASE="${DK_REGISTRY:+$DK_REGISTRY/}${BUILDER_NAME}:${BUILDER_TAG}"
BUILDER_ID_INC="${DK_REGISTRY:+$DK_REGISTRY/}${BUILDER_NAME}:${BUILDER_TAG_INC}"
BUILDER_ID_PACKAGE="${DK_REGISTRY:+$DK_REGISTRY/}${BUILDER_NAME}:${BUILDER_TAG_PACKAGE}"
_set_env BUILDER_ID_BASE BUILDER_ID_INC BUILDER_ID_PACKAGE

for var_dockerfile in ${!DOCKERFILE_@}; do
    eval ${var_dockerfile}="Dockerfiles/${!var_dockerfile}"
    _set_env ${var_dockerfile}
done

if [ "x${BUILD_MODE}" = "xinc" ]; then
    DK_IMAGE_BASE="${BUILDER_ID_INC}"
    DK_IMAGE_NAME="${BUILDER_NAME}"
    DK_IMAGE_TAG="${BUILDER_TAG_INC}"
    DK_DOCKERFILE="${DOCKERFILE_INC}"
elif [ "x${BUILD_MODE}" = "xpackage" ]; then
    DK_IMAGE_BASE="${BUILDER_ID_PACKAGE}"
    DK_IMAGE_NAME="${BUILDER_NAME}"
    DK_IMAGE_TAG="${BUILDER_TAG_PACKAGE}"
    DK_DOCKERFILE="${DOCKERFILE_PACKAGE}"
else
    echo "::error::Unknown BUILD_MODE='${BUILD_MODE}'" >&2
    exit 1
fi

_set_env DK_IMAGE_BASE DK_IMAGE_NAME DK_IMAGE_TAG DK_DOCKERFILE

if [ -z "${CONFIG_FILE}" -o ! -f "${CONFIG_FILE}" ]; then
    echo "CONFIG_FILE='${CONFIG_FILE}' does not exist, using default" >&2
    [ ! -z "${CONFIG_FILE_DEFAULT}" -a -f "${CONFIG_FILE_DEFAULT}" ] || ( echo "::error::CONFIG_FILE_DEFAULT='${CONFIG_FILE_DEFAULT}' does not exist!" >&2 && exit 1 )
    export CONFIG_FILE="${CONFIG_FILE_DEFAULT}"
    _set_env CONFIG_FILE
fi

_get_opt() {
OPT_NAME="${1}"
GITHUB_CONTEXT="${GITHUB_CONTEXT}" python3 <<EOF
import json, os
github_ctx = json.loads( os.environ["GITHUB_CONTEXT"] )
try:
  head_commit_message_opt = (github_ctx["event"]["head_commit"]["message"].find("#${OPT_NAME}#".lower()) != -1)
except KeyError:
  head_commit_message_opt = False

try:
  repo_dispatch_opt = github_ctx["event"]["client_payload"]["${OPT_NAME}".lower()]
except KeyError:
  repo_dispatch_opt = False

try:
  deployment_opt = github_ctx["event"]["deployment"]["payload"]["${OPT_NAME}".lower()]
except KeyError:
  deployment_opt = False

if (github_ctx["event_name"] == "push" and head_commit_message_opt) or repo_dispatch_opt or deployment_opt:
  print("1", end="")
else:
  print("0", end="")
EOF
}

_load_opt() {
    OPT_NAME="${1}"
    OPT_DEFAULT="${2:-0}"
    UPPER_OPT_NAME="$(echo "${OPT_NAME}" | tr '[:lower:]' '[:upper:]')"
    LOWER_OPT_NAME="$(echo "${OPT_NAME}" | tr '[:upper:]' '[:lower:]')"
    ENV_OPT_NAME="OPT_${UPPER_OPT_NAME}"
    eval ${ENV_OPT_NAME}="$(_get_opt "${LOWER_OPT_NAME}")"
    _set_env ${ENV_OPT_NAME}
}

for opt_name in ${BUILD_OPTS[@]}; do
    _load_opt "${opt_name}"
done

if [ "x${OPT_DEBUG}" = "x1" -a -z "${TMATE_ENCRYPT_PASSWORD}" -a -z "${SLACK_WEBHOOK_URL}" ]; then
    echo "::error::To use debug mode, you should set either TMATE_ENCRYPT_PASSWORD or SLACK_WEBHOOK_URL in the 'Secrets' page for safety of your sensitive information. For details, please refer to https://github.com/tete103%30/debugger-action/blob/master/README.md"
    echo "::error::In the reference URL you are instructed to use environment variables for them. However in this repo, you should set them in the 'Secrets' page"
    exit 1
fi
