#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

DK_LAYER_NUMBER_LIMIT=20 squash_image_when_necessary "${BUILDER_IMAGE_ID_INC}"
