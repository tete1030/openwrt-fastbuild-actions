#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

if [ "${LOCAL_RUN}" = "1" ]; then
    echo "Skipping setting docker"
    exit 0
fi

configure_docker
login_to_registry
