#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

TMP_BUILDER_IMAGE_ID="${BUILDER_IMAGE_ID_INC}-squashtmp"
docker tag "${BUILDER_IMAGE_ID_INC}" "${TMP_BUILDER_IMAGE_ID}"
docker push "${TMP_BUILDER_IMAGE_ID}"

set +eo pipefail
    CUR_IMAGE_DIGEST="$(docker buildx imagetools inspect --raw "${BUILDER_IMAGE_ID_INC}" | perl -pe 'chomp if eof' | openssl dgst -sha256 2>/dev/null ;  exit ${PIPESTATUS[0]})"
    image_check_ret_val=$?
set -eo pipefail

if [ "x${image_check_ret_val}" != "x0" ]; then
    echo "::error::Image disappeared!?" >&2
    exit 1
fi

if [ "x${CUR_IMAGE_DIGEST}" != "x${IMAGE_DIGEST}" ]; then
    echo "::error::Image '${BUILDER_IMAGE_ID_INC}' has changed during squashing, aborting" >&2
else
    create_remote_tag_alias "${TMP_BUILDER_IMAGE_ID}" "${BUILDER_IMAGE_ID_INC}"
fi
