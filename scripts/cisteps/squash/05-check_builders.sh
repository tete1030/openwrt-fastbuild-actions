#!/bin/bash
# shellcheck disable=SC2034
set -eo pipefail


# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"
# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/lib/gaction.sh"

# temporarily disable failure guarder
set +eo pipefail
    IMAGE_DIGEST="$(docker buildx imagetools inspect --raw "${BUILDER_IMAGE_ID_INC}" | perl -pe 'chomp if eof' | openssl dgst -sha256 2>/dev/null ;  exit ${PIPESTATUS[0]})"
    image_check_ret_val=$?
set -eo pipefail

if [ "x${image_check_ret_val}" != "x0" ]; then
    echo "No builder found, skipping"
    SKIP_TARGET=1
else
    SKIP_TARGET=0
fi
_set_env SKIP_TARGET IMAGE_DIGEST
