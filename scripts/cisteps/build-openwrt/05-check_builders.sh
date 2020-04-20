#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"
# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/lib/gaction.sh"

if [ "x${OPT_REBUILD}" != "x1" ]; then
  # temporarily disable failure guarder
  set +eo pipefail
  docker buildx imagetools inspect "${BUILDER_IMAGE_ID_INC}" > /dev/null 2>&1 
  builder_inc_ret_val=$?
  set -eo pipefail

  if [ "x${OPT_REBASE}" = "x1" ] || [ "x${builder_inc_ret_val}" != "x0" ]; then
  set +eo pipefail
    docker buildx imagetools inspect "${BUILDER_IMAGE_ID_BASE}" >/dev/null 2>&1
    builder_base_ret_val=$?
  set -eo pipefail
  if [ "x${builder_base_ret_val}" != "x0" ]; then
    echo "Base builder '${BUILDER_IMAGE_ID_BASE}' does not exist, creating one"
    OPT_REBUILD=1
  else
    echo "Creating incremental builder '${BUILDER_IMAGE_ID_INC}' from base builder '${BUILDER_IMAGE_ID_BASE}'"
    create_remote_tag_alias "${BUILDER_IMAGE_ID_BASE}" "${BUILDER_IMAGE_ID_INC}"
  fi
  fi
fi

if [ "x${OPT_REBUILD}" = "x1" ]; then
  echo "Re-creating base builder '${BUILDER_IMAGE_ID_BASE}'"
fi
_set_env OPT_REBUILD
