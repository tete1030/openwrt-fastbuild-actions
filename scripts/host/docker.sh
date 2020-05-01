#!/usr/bin/env bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

# # helper functions
# _exit_if_empty() {
#   local var_name=${1}
#   local var_value=${2}
#   if [ -z "$var_value" ]; then
#     echo "Missing input $var_name" >&2
#     exit 1
#   fi
# }

# # action steps
# check_required_input() {
#   _exit_if_empty DK_USERNAME "${DK_USERNAME}"
#   _exit_if_empty DK_PASSWORD "${DK_PASSWORD}"
# }

configure_docker() {
  echo '{
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50,
    "experimental": true
  }' | sudo tee /etc/docker/daemon.json
  sudo service docker restart
}

login_to_registry() {
  echo "${DK_PASSWORD}" | docker login -u "${DK_USERNAME}" --password-stdin "${DK_REGISTRY}"
}

pull_image() {
  local IMAGE_TO_PULL="${1}"
  if [ -n "${IMAGE_TO_PULL}" ]; then
    (
      set +eo pipefail
      docker pull "${IMAGE_TO_PULL}" 2> >(tee /tmp/dockerpull_stderr.log >&2)
      ret_val=$?
      if [ ${ret_val} -ne 0 ] && ( grep -q "max depth exceeded" /tmp/dockerpull_stderr.log ) ; then
        echo "::error::Your image has exceeded maximum layer limit. Normally this should have already been automatically handled, but obviously haven't. You need to manually rebase or rebuild this builder, or delete it on the Docker Hub website." >&2
        exit 1
      fi
      [ "x${STRICT_PULL}" != "x1" ] || exit $ret_val
    )
  else
    echo "No argument for pulling" >&2
    exit 1
  fi
}

squash_image_when_necessary() {
  if [ $# -ne 1 ]; then
    printf "Wrong parameters!\nUsage: squash_image_when_necessary IMAGE" >&2
    exit 1
  fi
  local SQUASH_IMAGE="${1}"

  local layer_number
  layer_number="$(docker image inspect -f '{{.RootFS.Layers}}' "${SQUASH_IMAGE}" | grep -o 'sha256:' | wc -l)"
  DK_LAYER_NUMBER_LIMIT=${DK_LAYER_NUMBER_LIMIT:-50}
  echo "Number of docker layers: ${layer_number}"
  if (( layer_number > DK_LAYER_NUMBER_LIMIT )); then
    echo "The number of docker layers has exceeded the limitation ${DK_LAYER_NUMBER_LIMIT}, squashing... (This may take some time)"
    # Use buildkit to squash since it squashes all layers together instead of just current Dockerfile
    # Though it is probably a bug not a feature: https://github.com/moby/moby/issues/38903
    # This is faster and reliable than tools like 'docker-squash'
    echo "Current docker system df:"
    docker system df
    echo "Current docker images:"
    docker image ls -a

    echo "FROM \"${SQUASH_IMAGE}\"" | DOCKER_BUILDKIT=1 docker build --squash "--tag=${SQUASH_IMAGE}" --file=- .
    echo "Squashing finished! Cleaning up dangling images ..."
    docker system prune -f

    echo "Current docker system df:"
    docker system df
    echo "Current docker images:"
    docker image ls -a
  fi
}

docker_exec() {
  (
    local exec_envs=()
    IFS=$'\x20'
    for env_name in ${DK_EXEC_ENVS}; do
      exec_envs+=( -e "${env_name}=${!env_name}" )
    done
    docker exec -i "${exec_envs[@]}" "$@"
  )
}

append_docker_exec_env() {
  for env_name in "$@"; do
    DK_EXEC_ENVS="${DK_EXEC_ENVS} ${env_name}"
  done
  DK_EXEC_ENVS="$(tr ' ' '\n' <<< "${DK_EXEC_ENVS}" | sort -u | tr '\n' ' ')"
}

create_remote_tag_alias() {
  docker buildx imagetools create -t "${2}" "${1}"
}

logout_from_registry() {
  docker logout "${DK_REGISTRY}"
}
