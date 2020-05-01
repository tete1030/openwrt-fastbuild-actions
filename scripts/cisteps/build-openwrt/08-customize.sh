#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/customize.sh"
