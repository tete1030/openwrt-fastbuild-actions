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
  echo "${DK_REGISTRY:+$DK_REGISTRY/}${DK_IMAGE_NAME}"
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

STAGE_AFFIX="-stage"
_get_stage_from_target() {
  echo "${1}${STAGE_AFFIX}"
}

STAGE_CVT_IMAGE_PREFIX="stage-cvt-image-"
_get_image_from_target() {
  echo "${STAGE_CVT_IMAGE_PREFIX}${1}"
}

# action steps
check_required_input() {
  _exit_if_empty DK_USERNAME "${DK_USERNAME}"
  _exit_if_empty DK_PASSWORD "${DK_PASSWORD}"
}

configure_docker() {
  echo '{
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50,
    "experimental": true
  }' | sudo tee /etc/docker/daemon.json
  sudo service docker restart
  docker buildx rm builder || true
  # shellcheck disable=SC2086
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
  IMAGE_TO_PULL="${1}"
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
  SQUASH_IMAGE="${1}"
  if [ "x${DK_BUILDX_DRIVER}" != "xdocker" ]; then
    echo "Buildx driver '${DK_BUILDX_DRIVER}' does not support image squashing" >&2
    exit 1
  fi

  LAYER_NUMBER=$(docker image inspect -f '{{.RootFS.Layers}}' "${SQUASH_IMAGE}" | grep -o 'sha256:' | wc -l)
  DK_LAYER_NUMBER_LIMIT=${DK_LAYER_NUMBER_LIMIT:-50}
  echo "Number of docker layers: ${LAYER_NUMBER}"
  if (( LAYER_NUMBER > DK_LAYER_NUMBER_LIMIT )); then
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

# Deprecated
build_image() {
  TARGET="${1}"

  IFS_ORI="$IFS"
  IFS=$'\x20'

  declare -a build_target
  declare -a build_args
  declare -a build_other_opts
  declare -a cache_from
  declare -a cache_to

  DK_DOCKERFILE_FULL="${DK_DOCKERFILE_FULL:-${DK_CONTEXT}/${DK_DOCKERFILE}}"

  TMP_DOCKERFILE_DIR="/tmp"
  DK_DOCKERFILE_TMP="${TMP_DOCKERFILE_DIR}/Dockerfile_build.tmp"
  if [ "x${DK_CONVERT_MULTISTAGE_TO_IMAGE}" = "x1" ]; then
    if [ "x${DK_BUILDX_DRIVER}" != "xdocker" ]; then
      echo "DK_CONVERT_MULTISTAGE_TO_IMAGE is only supported by buildx driver 'docker'" >&2
      exit 1
    fi
    if [ "x${DK_NO_REMOTE_CACHE}" != "x1" ]; then
      echo "DK_CONVERT_MULTISTAGE_TO_IMAGE does not support remote cache, please set DK_NO_REMOTE_CACHE to 1" >&2
      exit 1
    fi
    if [ "x${DK_NO_TAG}" = "x1" ]; then
      echo "DK_CONVERT_MULTISTAGE_TO_IMAGE requires tag option, please do not set DK_NO_TAG" >&2
      exit 1
    fi
    if [ "x${DK_NO_BUILDTIME_PUSH}" != "x1" ]; then
      echo "DK_CONVERT_MULTISTAGE_TO_IMAGE does not support buildtime pushing, please set DK_NO_BUILDTIME_PUSH to 1" >&2
      exit 1
    fi
    if [ -z "${TARGET}" ]; then
      echo "DK_CONVERT_MULTISTAGE_TO_IMAGE requires target option" >&2
      exit 1
    fi
    cp "${DK_DOCKERFILE_FULL}" "${DK_DOCKERFILE_TMP}"
    perl -pi -e 's/^(\s*FROM\s+)([\w-]+?)'${STAGE_AFFIX}'/\1'${STAGE_CVT_IMAGE_PREFIX}'\2/g' "${DK_DOCKERFILE_TMP}"
    DK_DOCKERFILE_FULL="${DK_DOCKERFILE_TMP}"
    DK_DOCKERFILE_STDIN=1
    build_other_opts+=( "--tag=$(_get_image_from_target "${TARGET}")" )
  fi

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
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ] && [ "x${DK_NO_CACHE_EXPT}" != "x1" ]; then
        echo "Docker build command does not support --cache-to=type=local" >&2
        exit 1
      fi
    else
      cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name_tag_for_build)" )
      if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ]; then
        cache_to+=( --build-arg "BUILDKIT_INLINE_CACHE=1" )
      else
        cache_to+=( "--cache-to=type=inline,mode=min" )
      fi
    fi
  else
    if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
      echo "Buildx driver 'docker' does not support registry cache" >&2
      exit 1
    fi
    if [ "x${DK_USE_INTEGRATED_BUILDKIT}" = "x1" ] && [ "x${DK_NO_CACHE_EXPT}" != "x1" ]; then
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
  echo "From cache: ${cache_from[*]}"
  if [ "x${DK_NO_CACHE_EXPT}" = "x1" ]; then
    echo "No saving cache"
    cache_to=()
  else
    echo "To cache: ${cache_to[*]}"
  fi
  
  if [ -n "${TARGET}" ]; then
    build_target+=( "--target=$(_get_stage_from_target "${TARGET}")" )
  fi

  if [ -n "${DK_BUILD_ARGS}" ]; then
    for arg in ${DK_BUILD_ARGS};
    do
      if [ -z "${!arg}" ]; then
        echo "Error: for error free coding, please do not leave variable \`${arg}\` empty. You can assign it a meaningless value if not used." >&2
        exit 1
      fi
      build_args+=( --build-arg "${arg}=${!arg}" )
    done
  fi
  
  if [ -n "${DK_OUTPUT}" ]; then
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
        build_other_opts+=( "--output=type=image,push=false" )
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
    DOCKER_BUILDKIT=1
    BUILD_COMMAND="build"
  else
    DOCKER_BUILDKIT=
  fi

  if [ "x${DK_DOCKERFILE_STDIN}" = "x1" ]; then
    (
      set -x
      # shellcheck disable=SC2086
      DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker ${BUILD_COMMAND} \
        "${build_target[@]}" \
        "${build_args[@]}" \
        "${cache_from[@]}" \
        "${cache_to[@]}" \
        "${build_other_opts[@]}" \
        ${DK_BUILDX_EXTRA_BUILD_OPTS} \
        --file=- \
        "${DK_CONTEXT}" <"${DK_DOCKERFILE_FULL}"
    )
  else
    (
      set -x
      # shellcheck disable=SC2086
      DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker ${BUILD_COMMAND} \
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

  if [ -n "${TARGET}" ] && [ "x${DK_NO_TARGET_RECORD}" != "x1" ]; then
    if [ "x${DK_CONVERT_MULTISTAGE_TO_IMAGE}" = "x1" ]; then
      LAST_BUILD_TARGET="$(_get_image_from_target "${TARGET}")"
    else
      LAST_BUILD_TARGET="$(_get_stage_from_target "${TARGET}")"
    fi
    echo "::set-env name=DK_LAST_BUILD_TARGET::${LAST_BUILD_TARGET}"
  fi

  IFS="$IFS_ORI"
}

# Deprecated
copy_files_from_image() {
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
    if [ -d "${COPY_CACHE_DIR}" ] && [ -n "$(ls -A "${COPY_CACHE_DIR}" 2>/dev/null)" ]; then
      echo "Error: \'${COPY_CACHE_DIR}\' directory already exists and not empty" >&2
      exit
    fi
    mkdir -p "${COPY_CACHE_DIR}" || true
    mkdir -p "${TMP_DOCKERFILE_DIR}" || true

    echo "Building copy task Dockerfile"
    DK_DOCKERFILE_FULL="${TMP_DOCKERFILE_DIR}/Dockerfile_copy.tmp"
    cp "${DK_CONTEXT}/${DK_DOCKERFILE}" "${DK_DOCKERFILE_FULL}"
    cat >> "${DK_DOCKERFILE_FULL}" << EOF
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

docker_exec() {
  (
    declare -a exec_envs=()
    IFS=$'\x20'
    for env_name in ${DK_EXEC_ENVS}; do
      exec_envs+=( -e "${env_name}=${!env_name}" )
    done
    docker exec -i "${exec_envs[@]}" "$@"
  )
}

# Deprecated
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

# Deprecated
push_image() {
  if [ "x${DK_NO_BUILDTIME_PUSH}" = "x1" ]; then
    if [ "x${DK_BUILDX_DRIVER}" = "xdocker" ]; then
      docker push "$(_get_full_image_name_tag_for_build)"
    else
      echo "Warning: pushing in '${DK_BUILDX_DRIVER}' driver can be very slow, because the final image needs to be unpacked and repacked again"
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

# Deprecated
push_cache() {
  if [ "x${DK_NO_REMOTE_CACHE}" = "x1" ]; then
    echo "DK_NO_REMOTE_CACHE is set, no cache to push" >&2
  else
    create_remote_tag_alias "$(_get_full_image_name_tag_for_build_cache)" "$(_get_full_image_name_tag_for_cache)" 
  fi
}

# Deprecated
push_image_and_cache() {
  push_image
  push_cache
}

logout_from_registry() {
  docker logout "${DK_REGISTRY}"
}

check_required_input
