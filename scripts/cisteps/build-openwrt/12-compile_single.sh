#!/bin/bash

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

docker_exec -e MODE=s "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/compile.sh"
