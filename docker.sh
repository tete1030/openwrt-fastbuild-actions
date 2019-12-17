#!/usr/bin/env bash

set -eo pipefail

# helper functions
_exit_if_empty() {
  local var_name=${1}
  local var_value=${2}
  if [ -z "$var_value" ]; then
    echo "Missing input $var_name" >&2
    exit 1
  fi
}

_get_full_image_name() {
  echo ${REGISTRY:+$REGISTRY/}${IMAGE_NAME}
}

# action steps
check_required_input() {
  _exit_if_empty USERNAME "${USERNAME}"
  _exit_if_empty PASSWORD "${PASSWORD}"
  _exit_if_empty IMAGE_NAME "${IMAGE_NAME}"
  _exit_if_empty IMAGE_TAG "${IMAGE_TAG}"
  _exit_if_empty CONTEXT "${CONTEXT}"
  _exit_if_empty DOCKERFILE "${DOCKERFILE}"
}

configure_docker() {
  echo '{
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50
  }' | sudo tee /etc/docker/daemon.json
  sudo service docker restart
}

login_to_registry() {
  echo "${PASSWORD}" | docker login -u "${USERNAME}" --password-stdin "${REGISTRY}"
}

pull_image() {
  docker pull --all-tags "$(_get_full_image_name)" 2> /dev/null || true
}

build_image() {
  cache_from="$cache_from --cache-from=$(_get_full_image_name):${IMAGE_TAG}"
  echo "Use cache: $cache_from"

  build_target=()
  if [ ! -z "${1}" ]; then
    build_target+=(--target "${1}")
  fi
  build_args=()
  if [ ! -z "${BUILD_ARGS}" ]; then
    IFS_ORI="$IFS"
    IFS=$'\x20'
    
    for arg in ${BUILD_ARGS[@]};
    do
      build_args+=(--build-arg "${arg}=${!arg}")
    done
    IFS="$IFS_ORI"
  fi

  # build image using cache
  DOCKER_BUILDKIT=1 docker build \
    "${build_target[@]}" \
    "${build_args[@]}" \
    $cache_from \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --tag "$(_get_full_image_name)":${IMAGE_TAG} \
    --file ${CONTEXT}/${DOCKERFILE} \
    ${CONTEXT}
}

mount_container() {
  docker container create --name builder -v "${1}:${2}" "$(_get_full_image_name)":${IMAGE_TAG}
}

push_git_tag() {
  [[ "$GITHUB_REF" =~ /tags/ ]] || return 0
  local git_tag=${GITHUB_REF##*/tags/}
  local image_with_git_tag
  image_with_git_tag="$(_get_full_image_name)":$git_tag
  docker tag "$(_get_full_image_name)":${IMAGE_TAG} "$image_with_git_tag"
  docker push "$image_with_git_tag"
}

push_image() {
  # push image
  docker push "$(_get_full_image_name)":${IMAGE_TAG}
  push_git_tag
}

logout_from_registry() {
  docker logout "${REGISTRY}"
}

check_required_input
