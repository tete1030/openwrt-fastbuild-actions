#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

# 'eval' is to correctly parse quotes
eval "declare -a MOUNT_OPTS=( ${BUILDER_MOUNT_OPTS} )"
if [ "x${OPT_REBUILD}" != "x1" ]; then
  pull_image "${BUILDER_IMAGE_ID_INC}"
  squash_image_when_necessary "${BUILDER_IMAGE_ID_INC}"
  docker run -d -t --name "${BUILDER_CONTAINER_ID}" "${MOUNT_OPTS[@]}" "${BUILDER_IMAGE_ID_INC}"
else
  docker run -d -t --name "${BUILDER_CONTAINER_ID}" "${MOUNT_OPTS[@]}" "${BUILDER_IMAGE_ID_BUILDENV}"
fi
docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/init_env.sh"
