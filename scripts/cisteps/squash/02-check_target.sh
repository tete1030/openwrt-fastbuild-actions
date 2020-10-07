#!/bin/bash
# shellcheck disable=SC2034

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/lib/gaction.sh"

SKIP_TARGET=1
if [[ ( "${GITHUB_EVENT_NAME}" == "repository_dispatch" || "${GITHUB_EVENT_NAME}" == "deployment" ) && "${RD_TASK}" == "squash" && ( "${RD_TARGET}" == "all" || "${RD_TARGET}" == "${BUILD_TARGET}" || "${RD_TARGET}" == *"#${BUILD_TARGET}#"* ) ]]; then
    SKIP_TARGET=0
elif [[ "${GITHUB_EVENT_NAME}" == "schedule" ]]; then
    SKIP_TARGET=0
elif [[ "${GITHUB_EVENT_NAME}" == "workflow_dispatch" && ( "${RD_TARGET}" == "all" || "${RD_TARGET}" == "${BUILD_TARGET}" || "${RD_TARGET}" == *"#${BUILD_TARGET}#"* ) ]]; then
    SKIP_TARGET=0
fi
_set_env SKIP_TARGET
