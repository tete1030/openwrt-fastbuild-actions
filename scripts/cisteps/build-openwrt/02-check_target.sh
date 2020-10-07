#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/lib/gaction.sh"

SKIP_TARGET=1
if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
  if [ -n "${RD_TARGET}" ]; then
    echo "Commit message target: ${RD_TARGET}"
    if [ "x${RD_TARGET}" = "xall" ] || [ "x${RD_TARGET}" = "x${BUILD_TARGET}" ]; then
      SKIP_TARGET=0
    fi
  else
    commit_before=$(jq -crM '.before // ""' "${GITHUB_EVENT_PATH}")
    commit_after=$(jq -crM '.after // ""' "${GITHUB_EVENT_PATH}")
    if [ -z "${commit_before}" ] || [ -z "${commit_after}" ]; then
      echo "::error::Oops! Something went wrong! Github push event does not exist!" >&2
      exit 1
    fi

    # when forcing push, we cannot compare
    if git cat-file -e "${commit_before}^{commit}" ; then
      echo "Changes in this push:"
      git --no-pager diff --name-status "${commit_before}" "${commit_after}"
      changed_files="$(git --no-pager diff --name-only "${commit_before}" "${commit_after}")"

      # shellcheck disable=SC2001
      BUILD_TARGET_ESC="$(echo -n "${BUILD_TARGET}" | sed 's/[^[:alnum:]_-]/\\&/g')"
      target_files_changed=0
      set +eo pipefail
        echo "${changed_files}" | grep -q '^user/'"${BUILD_TARGET_ESC}"'/'
        target_ret_val=$?
        if [ ${target_ret_val} -eq 0 ]; then
          target_files_changed=1
        else
          default_changed_files_to_target="$(echo "${changed_files}" | grep '^user/default/' | sed 's/^user\/default\//user\/'"${BUILD_TARGET_ESC}"'\//g')"
          while IFS= read -r line; do
            if [ -n "${line// }" ] && [ ! -e "$line" ]; then
              target_files_changed=1
              break
            fi
          done <<< "${default_changed_files_to_target}"
        fi
      set -eo pipefail

      if [ ${target_files_changed} -eq 1 ]; then
        echo "File changes of current target detected"
        SKIP_TARGET=0
      fi
    else
      echo "::error::Force push detected, we cannot compare file changes" >&2
    fi
  fi

elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ] || [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
  echo "Repo dispatch or deployment event task: ${RD_TASK} target: ${RD_TARGET}"
  if [[ "${RD_TASK}" == "build" && ( "${RD_TARGET}" == "all" || "${RD_TARGET}" == "${BUILD_TARGET}" || "${RD_TARGET}" == *"#${BUILD_TARGET}#"* ) ]]; then
    SKIP_TARGET=0
  fi
elif [ "x${GITHUB_EVENT_NAME}" = "xworkflow_dispatch" ]; then
  echo "Workflow dispatch event target: ${RD_TARGET}"
  if [[ "${RD_TARGET}" == "all" || "${RD_TARGET}" == "${BUILD_TARGET}" || "${RD_TARGET}" == *"#${BUILD_TARGET}#"* ]]; then
    SKIP_TARGET=0
  fi
else
  echo "::warning::Unknown default target for triggering event: ${GITHUB_EVENT_NAME}" >&2
  SKIP_TARGET=0
fi

if [ "x${SKIP_TARGET}" = "x1" ]; then
  echo "Skipping current job"
else
  echo "Not skipping current job"
fi
_set_env SKIP_TARGET
