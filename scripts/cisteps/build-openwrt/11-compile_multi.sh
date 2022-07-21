#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

if [ -f "/tmp/failed_packages.txt" ]; then
    rm -f /tmp/failed_packages.txt
fi

echo "::set-output name=started::1"
docker_exec -e MODE=m "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/compile.sh"
echo "::set-output name=status::success"
