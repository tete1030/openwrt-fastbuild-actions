#!/usr/bin/env bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

# WARNING: Do not try to modify this file if you don't understand it as
# this script is not very robust.

if [ "x$NO_FAILEXIT" != "x1" ]; then
  set -eo pipefail
fi

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
  echo ${DK_REGISTRY:+$DK_REGISTRY/}${DK_IMAGE_NAME}
}

_get_full_image_name_tag() {
  echo "$(_get_full_image_name):${DK_IMAGE_TAG}"
}

_get_full_image_name_tag_for_build() {
  echo "$(_get_full_image_name_tag)-build"
}

_get_full_image_name_tag_for_build_cache() {
  echo "$(_get_full_image_name_tag)-buildcache"
}

_get_full_image_name_tag_for_cache() {
  echo "$(_get_full_image_name_tag)-cache"
}

# action steps
check_required_input() {
  _exit_if_empty DK_USERNAME "${DK_USERNAME}"
  _exit_if_empty DK_PASSWORD "${DK_PASSWORD}"
  _exit_if_empty DK_IMAGE_NAME "${DK_IMAGE_NAME}"
  _exit_if_empty DK_IMAGE_TAG "${DK_IMAGE_TAG}"
  _exit_if_empty DK_CONTEXT "${DK_CONTEXT}"
  _exit_if_empty DK_DOCKERFILE "${DK_DOCKERFILE}"
}

configure_docker() {
  echo '{
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50,
    "experimental": true
  }' | sudo tee /etc/docker/daemon.json
  sudo service docker restart
  docker buildx rm builder || true
  docker buildx create --use --name builder --node builder0 --driver docker-container ${DK_BUILDX_EXTRA_CREATE_OPTS}
  reconfigure_docker_buildx
}

# Texot:
# Why buildx? Why different driver? Why complicated copying strategy?
# 
# The reason I use Docker BuildKit instead of original docker is that
# buildx with docker-container driver supports full cache of multi-stage
# building. This accelerates current and future building process.
# 
# However, with this driver, the built image must be uploaded to registry
# or created image would be immediately deleted. When using multi-stage
# building with a registry base image ( Dockerfile: FROM a_large_image ),
# the base image would be re-downloaded and re-unpacked for each target 
# instead of using cached base image. Therefore, when base image is large, 
# the buildx driver 'docker' is used.
#
# To copy files out from docker-container builder, since 'docker cp'
# command does not work here, I am using direct export of image files. To
# make the export minimum, using an scratch image with only necessary files
# copied is a more efficient method.
# 
# There are also many other tricky parts in this project. To learn more,
# feel free to raise an issue in github.com/tete1030/Actions_OpenWrt

reconfigure_docker_buildx() {
  if [ -z "${DK_BUILDX_DRIVER}" ]; then
    echo "DK_BUILDX_DRIVER not specified" >&2
    exit 1
  fi
  if [ "x${DK_BUILDX_DRIVER}" = "xdocker-container" ]; then
    echo "Use buildx driver: docker-container"
    docker buildx use builder
  elif [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
    echo "Use buildx driver: docker"
    docker buildx use default
  else
    echo "Unknown buildx driver" >&2
    exit 1
  fi
}

login_to_registry() {
  echo "${DK_PASSWORD}" | docker login -u "${DK_USERNAME}" --password-stdin "${DK_REGISTRY}"
}

pull_image() {
  if [ "x${DK_BUILDX_DRIVER}" != "xdocker" ]; then
    echo "Buildx driver '${DK_BUILDX_DRIVER}' does not support pulling and image management" >&2
    exit 1
  fi
  # docker pull --all-tags "$(_get_full_image_name)" 2> /dev/null || true
  if [ ! -z "${DK_IMAGE_BASE}" ]; then
    docker pull "${DK_IMAGE_BASE}" 2> /dev/null || true
  else
    echo "No DK_IMAGE_BASE configured for pulling" >&2
    exit 1
  fi
}

build_image() {
  TARGET="${1}"

  IFS_ORI="$IFS"
  IFS=$'\x20'

  declare -a cache_from
  declare -a cache_to

  if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
    if [ "x${DK_BUILDX_DRIVER}" != "xdocker" ]; then
      echo "Docker build command does not support other drivers than 'docker'" >&2
      exit 1
    fi
  fi

  if [ "x${DK_NO_REMOTE_CACHE}" = "x1" ]; then
    if [ "x${DK_NO_INLINE_CACHE}" = "x1" ]; then
      if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
        echo "Buildx driver 'docker' does not support local cache" >&2
        exit 1
      fi
      if [ -f "./cache/index.json" ]; then
        cache_from+=( "--cache-from=type=local,src=./cache" )
      fi
      cache_to+=( "--cache-to=type=local,dest=./cache" )
      if [ ! -d "./cache" ]; then
        mkdir ./cache
      fi
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" -a "x${DK_NO_CACHE_EXPT}" != "x1" ]; then
        echo "Docker build command does not support --cache-to=type=local" >&2
        exit 1
      fi
    else
      cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name_tag_for_build)" )
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
        cache_to+=( --build-arg BUILDKIT_INLINE_CACHE=1 )
      else
        cache_to+=( "--cache-to=type=inline,mode=min" )
      fi
    fi
  else
    if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
      echo "Buildx driver 'docker' does not support registry cache" >&2
      exit 1
    fi
    if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" -a "x${DK_NO_CACHE_EXPT}" != "x1" ]; then
      echo "Docker build command does not support --cache-to=type=registry" >&2
      exit 1
    fi
    # 'cache' is for cache from previous build
    # 'buildcache' is for cache from current build
    # This is to prevent overriding cache during multi-stage building
    # We will eventually rename 'buildcache' to 'cache'. At initial and final stage, they are the same
    cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name_tag_for_cache)" )
    cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name_tag_for_build_cache)" )
    cache_to+=( "--cache-to=type=registry,ref=$(_get_full_image_name_tag_for_build_cache),mode=max" )
  fi
  echo "From cache: ${cache_from[@]}"
  if [ "x${DK_NO_CACHE_EXPT}" = "x1" ]; then
    echo "No saving cache"
    cache_to=()
  else
    echo "To cache: ${cache_to[@]}"
  fi

  declare -a build_target
  if [ ! -z "${TARGET}" ]; then
    build_target+=( "--target=${TARGET}" )
  fi
  declare -a build_args
  if [ ! -z "${DK_BUILD_ARGS}" ]; then
    for arg in ${DK_BUILD_ARGS[@]};
    do
      if [ -z "${!arg}" ]; then
        echo "Error: for error free coding, please do not leave variable \`${arg}\` empty. You can assign it a meaningless value if not used." >&2
        exit 1
      fi
      build_args+=( --build-arg "${arg}=${!arg}" )
    done
  fi

  declare -a build_other_opts
  if [ ! -z "${DK_OUTPUT}" ]; then
    if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
      echo "Warning: docker build command may not support this output type" >&2
    fi
    build_other_opts+=( "--output=${DK_OUTPUT}" )
  else
    if [ "x${DK_NO_BUILDTIME_PUSH}" = "x1" ]; then
      if [ "x${DK_BUILDX_DRIVER}" != "xdocker" ]; then
        echo "Warning: buildx driver '${DK_BUILDX_DRIVER}' does not support image management. Images may lose when not pushing." >&2
      fi
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" != "x1" ]; then
        build_other_opts+=( --output=type=image,push=false )
      fi
    else
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
        echo "Docker build does not support build-time push" >&2
        exit 1
      fi
      build_other_opts+=( --push )
    fi
  fi
  if [ "x${DK_NO_TAG}" != "x1" ]; then
    build_other_opts+=( "--tag=$(_get_full_image_name_tag_for_build)" )
  fi

  if [ "x${SQUASH}" = "x1" ]; then
    if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
      build_other_opts+=( "--squash" )
    else
      echo "Buildx does not support squash" >&2
      exit 1
    fi
  fi

  BUILD_COMMAND="buildx build"
  if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
    export DOCKER_BUILDKIT=1
    BUILD_COMMAND="build"
  fi

  DK_DOCKERFILE_FULL=${DK_DOCKERFILE_FULL:-${DK_CONTEXT}/${DK_DOCKERFILE}}

  if [ "x${DK_DOCKERFILE_STDIN}" = "x1" ]; then
    (
      set -x
      docker ${BUILD_COMMAND} \
        "${build_target[@]}" \
        "${build_args[@]}" \
        "${cache_from[@]}" \
        "${cache_to[@]}" \
        "${build_other_opts[@]}" \
        ${DK_BUILDX_EXTRA_BUILD_OPTS} \
        --file=- \
        "${DK_CONTEXT}" < "${DK_DOCKERFILE_FULL}"
    )
  else
    (
      set -x
      docker ${BUILD_COMMAND} \
        "${build_target[@]}" \
        "${build_args[@]}" \
        "${cache_from[@]}" \
        "${cache_to[@]}" \
        "${build_other_opts[@]}" \
        ${DK_BUILDX_EXTRA_BUILD_OPTS} \
        "--file=${DK_DOCKERFILE_FULL}" \
        "${DK_CONTEXT}"
    )
  fi

  if [ ! -z "${TARGET}" -a "x${DK_NO_TARGET_RECORD}" != "x1" ]; then
    echo "::set-env name=DK_LAST_BUILD_TARGET::${TARGET}"
  fi

  IFS="$IFS_ORI"
}

copy_files() {
  SOURCE_IMAGE="$(_get_full_image_name_tag_for_build)"
  if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
    echo "Buildx driver 'docker', using direct copying method"
    docker run -d -i --rm --name builder "${SOURCE_IMAGE}"
    docker cp builder:"$1" "$2"
    docker stop builder
  else
    # When built image is large, this process can be extremely slow
    COPY_CACHE_DIR="cache/buildresult"
    BUILDRESULT_IMAGE_DIR="/buildresult"
    TMP_DOCKERFILE_DIR="/tmp"
    
    echo "Buildx driver '${DK_BUILDX_DRIVER}', using indirect copying method"
    DK_LAST_BUILD_TARGET="${3:-${DK_LAST_BUILD_TARGET}}"
    if [ -z "${DK_LAST_BUILD_TARGET}" ]; then
      echo "DK_LAST_BUILD_TARGET not set" >&2
      exit 1
    fi
    echo "Using DK_LAST_BUILD_TARGET='${DK_LAST_BUILD_TARGET}'"
    if [ -d "${COPY_CACHE_DIR}" -a ! -z "$(eval ls -A \"${COPY_CACHE_DIR}\" 2>/dev/null)" ]; then
      echo "Error: \'${COPY_CACHE_DIR}\' directory already exists and not empty" >&2
      exit
    fi
    mkdir -p "${COPY_CACHE_DIR}" || true
    mkdir -p "${TMP_DOCKERFILE_DIR}" || true

    echo "Building copy task Dockerfile"
    DK_DOCKERFILE_FULL="${TMP_DOCKERFILE_DIR}/Dockerfile.tmp"
    cp "${DK_CONTEXT}/${DK_DOCKERFILE}" "${TMP_DOCKERFILE_DIR}/Dockerfile.tmp"
    cat >> "${TMP_DOCKERFILE_DIR}/Dockerfile.tmp" << EOF
FROM scratch AS buildresult
WORKDIR "${BUILDRESULT_IMAGE_DIR}"
COPY --from="${DK_LAST_BUILD_TARGET}" "${1}" ./copied
EOF

    echo "Building copy task image"
    (
      export DK_NO_CACHE_EXPT=1
      export DK_NO_TAG=1
      export DK_NO_TARGET_RECORD=1
      export DK_OUTPUT="type=local,dest=${COPY_CACHE_DIR}"
      export DK_DOCKERFILE_FULL
      export DK_DOCKERFILE_STDIN=1
      build_image buildresult
    )

    mv "${COPY_CACHE_DIR}/${BUILDRESULT_IMAGE_DIR}/copied" "${2}"
    all_other_files=( "${COPY_CACHE_DIR}"/* )
    rm -rf "${all_other_files[@]}" || true
  fi
}

push_git_tag() {
  [[ "$GITHUB_REF" =~ /tags/ ]] || return 0
  local git_tag=${GITHUB_REF##*/tags/}
  local image_with_git_tag
  image_with_git_tag="$(_get_full_image_name):gittag-$git_tag"
  # docker tag "$(_get_full_image_name_tag)" "$image_with_git_tag"
  # docker push "$image_with_git_tag"
  create_remote_tag_alias "$(_get_full_image_name_tag)" "$image_with_git_tag" 
}

create_remote_tag_alias() {
  docker buildx imagetools create -t "${2}" "${1}"
}

push_image() {
  if [ "x${DK_NO_BUILDTIME_PUSH}" = "x1" ]; then
    if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
      docker push "$(_get_full_image_name_tag_for_build)"
    else
      echo "Warning: separated pushing in '${DK_BUILDX_DRIVER}' driver can be very slow, because the final image needs to be unpacked and repacked again"
      if [ -z "${DK_LAST_BUILD_TARGET}" ]; then
        echo "DK_LAST_BUILD_TARGET not set" >&2
        exit 1
      fi
      DK_NO_BUILDTIME_PUSH=0 DK_NO_TARGET_RECORD=1 build_image "${DK_LAST_BUILD_TARGET}"
    fi
  fi
  # push image
  # docker push "$(_get_full_image_name_tag)"
  create_remote_tag_alias "$(_get_full_image_name_tag_for_build)" "$(_get_full_image_name_tag)" 
  # push_git_tag
}

push_cache() {
  if [ "x${DK_NO_REMOTE_CACHE}" = "x1" ]; then
    echo "DK_NO_REMOTE_CACHE is set, no cache to push" >&2
  else
    create_remote_tag_alias "$(_get_full_image_name_tag_for_build_cache)" "$(_get_full_image_name_tag_for_cache)" 
  fi
}

push_image_and_cache() {
  push_image
  push_cache
}

logout_from_registry() {
  docker logout "${DK_REGISTRY}"
}

check_required_input
