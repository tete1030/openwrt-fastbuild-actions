#!/usr/bin/env bash

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
  configure_docker_buildx
}

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

configure_docker_buildx() {
  if [ -z "${BUILDX_DRIVER}" ]; then
    echo "BUILDX_DRIVER not specified" >&2
    exit 1
  fi
  docker buildx rm builder || true
  if [ "x${BUILDX_DRIVER}" = "xdocker-container" ]; then
    echo "Use buildx driver: docker-container"
    docker buildx create --use --name builder --node builder0 --driver docker-container ${EXTRA_BUILDX_CREATE_OPTS}
  elif [ "x${BUILDX_DRIVER}" = "xdocker" ]; then
    echo "Use buildx driver: docker"
    docker buildx use default
  else
    echo "Unknown buildx driver" >&2
    exit 1
  fi
}

login_to_registry() {
  echo "${PASSWORD}" | docker login -u "${USERNAME}" --password-stdin "${REGISTRY}"
}

pull_image() {
  if [ "x${BUILDX_DRIVER}" != "xdocker" ]; then
    echo "Buildx driver '${BUILDX_DRIVER}' does not support pulling and image management" >&2
    exit 1
  fi
  # docker pull --all-tags "$(_get_full_image_name)" 2> /dev/null || true
  if [ ! -z "${IMAGE_BASE}" ]; then
    docker pull "${IMAGE_BASE}" 2> /dev/null || true
  else
    echo "No IMAGE_BASE configured for pulling" >&2
    exit 1
  fi
}

build_image() {
  IFS_ORI="$IFS"
  IFS=$'\x20'
  declare -a cache_from
  declare -a cache_to

  if [ "x${NO_REMOTE_CACHE}" = "x1" ]; then
    if [ "x${NO_INLINE_CACHE}" = "x1" ]; then
      if [ "x${BUILDX_DRIVER}" = "xdocker" ]; then
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
    else
      cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name):${IMAGE_TAG}-build" )
      cache_to+=( "--cache-to=type=inline,mode=min" )
    fi
  else
    if [ "x${BUILDX_DRIVER}" = "xdocker" ]; then
      echo "Buildx driver 'docker' does not support registry cache" >&2
      exit 1
    fi
    # 'cache' is for cache from previous build
    # 'buildcache' is for cache from current build
    # This is to prevent overriding cache during multi-stage building
    # We will eventually rename 'buildcache' to 'cache'. At initial and final stage, they are the same
    cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name):cache" )
    cache_from+=( "--cache-from=type=registry,ref=$(_get_full_image_name):buildcache" )
    cache_to+=( "--cache-to=type=registry,ref=$(_get_full_image_name):buildcache,mode=max" )
  fi
  echo "From cache: ${cache_from[@]}"
  if [ "x${NO_CACHE_TO}" = "x1" ]; then
    echo "No saving cache"
    cache_to=()
  else
    echo "To cache: ${cache_to[@]}"
  fi

  declare -a build_target
  if [ ! -z "${1}" ]; then
    build_target+=( "--target=${1}" )
  fi
  declare -a build_args
  if [ ! -z "${BUILD_ARGS}" ]; then
    for arg in ${BUILD_ARGS[@]};
    do
      if [ -z "${!arg}" ]; then
        echo "Warning: variable \`${arg}\` is empty" >&2
      fi
      build_args+=( --build-arg "${arg}=${!arg}" )
    done
  fi

  declare -a build_other_opts
  if [ ! -z "${OUTPUT}" ]; then
    build_other_opts+=( "--output=${OUTPUT}" )
  else
    if [ "x${NO_PUSH}" = "x1" ]; then
      if [ "x${BUILDX_DRIVER}" != "xdocker" ]; then
        echo "Warning: buildx driver '${BUILDX_DRIVER}' does not support image management. Images may lose when not pushing." >&2
      fi
      build_other_opts+=( --output=type=image,push=false )
    else
      build_other_opts+=( --push )
    fi
  fi
  if [ "x${NO_TAG}" != "x1" ]; then
    build_other_opts+=( "--tag=$(_get_full_image_name):${IMAGE_TAG}-build" )
  fi

  DOCKERFILE_FULL=${DOCKERFILE_FULL:-${CONTEXT}/${DOCKERFILE}}

  if [ "x${DOCKERFILE_STDIN}" = "x1" ]; then
    (
      set -x
      docker buildx build \
        "${build_target[@]}" \
        "${build_args[@]}" \
        "${cache_from[@]}" \
        "${cache_to[@]}" \
        "${build_other_opts[@]}" \
        ${EXTRA_BUILDX_BUILD_OPTS} \
        --file=- \
        "${CONTEXT}" < "${DOCKERFILE_FULL}"
    )
  else
    (
      set -x
      docker buildx build \
        "${build_target[@]}" \
        "${build_args[@]}" \
        "${cache_from[@]}" \
        "${cache_to[@]}" \
        "${build_other_opts[@]}" \
        ${EXTRA_BUILDX_BUILD_OPTS} \
        "--file=${DOCKERFILE_FULL}" \
        "${CONTEXT}"
    )
  fi

  IFS="$IFS_ORI"
}

copy_files() {
  SOURCE_IMAGE="$(_get_full_image_name):${IMAGE_TAG}-build"
  if [ "x${BUILDX_DRIVER}" = "xdocker" ]; then
    echo "Buildx driver 'docker', using direct copying method"
    docker run -d -i --rm --name builder "${SOURCE_IMAGE}"
    docker cp builder:"$1" "$2"
    docker stop builder
  else
    COPY_CACHE_DIR="cache/buildresult"
    BUILDRESULT_IMAGE_DIR="/buildresult"
    TMP_DOCKERFILE_DIR="/tmp"
    
    echo "Buildx driver '${BUILDX_DRIVER}', using indirect copying method"
    LAST_BUILD_STAGE="${3:-${LAST_BUILD_STAGE}}"
    if [ -z "${LAST_BUILD_STAGE}" ]; then
      echo "LAST_BUILD_STAGE not set" >&2
      exit 1
    fi
    echo "Using LAST_BUILD_STAGE='${LAST_BUILD_STAGE}'"
    if [ -d "${COPY_CACHE_DIR}" -a ! -z "$(eval ls -A \"${COPY_CACHE_DIR}\" 2>/dev/null)" ]; then
      echo "Error: \'${COPY_CACHE_DIR}\' directory already exists and not empty" >&2
      exit
    fi
    mkdir -p "${COPY_CACHE_DIR}" || true
    mkdir -p "${TMP_DOCKERFILE_DIR}" || true

    echo "Building copy task Dockerfile"
    DOCKERFILE_FULL="${TMP_DOCKERFILE_DIR}/Dockerfile.tmp"
    cp "${CONTEXT}/${DOCKERFILE}" "${TMP_DOCKERFILE_DIR}/Dockerfile.tmp"
    cat >> "${TMP_DOCKERFILE_DIR}/Dockerfile.tmp" << EOF
FROM scratch AS buildresult
WORKDIR "${BUILDRESULT_IMAGE_DIR}"
COPY --from="${LAST_BUILD_STAGE}" "${1}" ./
EOF

    echo "Building copy task image"
    (
      export NO_CACHE_TO=1
      export NO_TAG=1
      export OUTPUT="type=local,dest=${COPY_CACHE_DIR}"
      export DOCKERFILE_FULL
      export DOCKERFILE_STDIN=1
      build_image buildresult
    )
    
    all_files=( "${COPY_CACHE_DIR}/${BUILDRESULT_IMAGE_DIR}"/* )
    mv "${all_files[@]}" "${2}"
    all_other_files=( "${COPY_CACHE_DIR}"/* )
    rm -rf "${all_other_files[@]}" || true
  fi
}

push_git_tag() {
  [[ "$GITHUB_REF" =~ /tags/ ]] || return 0
  local git_tag=${GITHUB_REF##*/tags/}
  local image_with_git_tag
  image_with_git_tag="$(_get_full_image_name):gittag-$git_tag"
  # docker tag "$(_get_full_image_name):${IMAGE_TAG}" "$image_with_git_tag"
  # docker push "$image_with_git_tag"
  docker buildx imagetools create -t "$image_with_git_tag" "$(_get_full_image_name):${IMAGE_TAG}"
}

push_image_and_cache() {
  if [ "x${NO_PUSH}" = "x1" ]; then
    if [ "x${BUILDX_DRIVER}" = "xdocker" ]; then
      docker push "$(_get_full_image_name):${IMAGE_TAG}-build"
    else
      echo "Warning: separated pushing in '${BUILDX_DRIVER}' driver can be slow, because final image needs to be rebuilt from previous cache"
      if [ -z "${LAST_BUILD_STAGE}" ]; then
        echo "LAST_BUILD_STAGE not set" >&2
        exit 1
      fi
      NO_PUSH=0 build_image "${LAST_BUILD_STAGE}"
    fi
  fi
  # push image
  # docker push "$(_get_full_image_name):${IMAGE_TAG}"
  docker buildx imagetools create -t "$(_get_full_image_name):${IMAGE_TAG}" "$(_get_full_image_name):${IMAGE_TAG}-build"
  docker buildx imagetools create -t "$(_get_full_image_name):cache" "$(_get_full_image_name):buildcache"
  # push_git_tag
}

logout_from_registry() {
  docker logout "${REGISTRY}"
}

check_required_input
