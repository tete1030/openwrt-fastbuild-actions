#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

STRICT_PULL=1 pull_image "${BUILDER_IMAGE_ID_INC}"
