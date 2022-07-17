#!/bin/bash

set -eo pipefail

clean_up_docker() {
  docker container prune -f
  docker system prune -f --volumes
}

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/pre_commit.sh"
docker commit -a "tete1030/openwrt-fastbuild-actions" -m "Building at $(date)" "${BUILDER_CONTAINER_ID}" "${BUILDER_IMAGE_ID_INC}"
docker container rm -fv "${BUILDER_CONTAINER_ID}"

if [ "x${LOCAL_RUN}" == "x1" ]; then
  echo "Skipping cleaning up and squashing"
else
  clean_up_docker
  if [ "x${OPT_REBUILD}" != 'x1' ]; then
    squash_image_when_necessary "${BUILDER_IMAGE_ID_INC}"
  fi
fi

docker push "${BUILDER_IMAGE_ID_INC}"
if [ "x${OPT_REBUILD}" = "x1" ]; then
  create_remote_tag_alias "${BUILDER_IMAGE_ID_INC}" "${BUILDER_IMAGE_ID_BASE}"
fi
