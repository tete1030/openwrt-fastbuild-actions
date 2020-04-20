#!/bin/bash

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

configure_docker
login_to_registry
