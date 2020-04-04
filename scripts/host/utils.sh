#!/bin/bash

_check_missing_vars() {
  local missing_vars=()
  for var_name in "$@" ; do
    if [ -z "${!var_name}" ]; then
      missing_vars+=( "${var_name}" )
    fi
  done
  echo -n "${missing_vars[@]}"
}

_set_env() {
  for var_name in "$@" ; do
    # unescape %0A and %0D, source: https://github.community/t5/GitHub-Actions/set-output-Truncates-Multiline-Strings/td-p/37870
    # but no unescape of %25 ??? https://github.com/actions/runner/blob/6c70d53eea/src/Runner.Common/ActionCommand.cs#L19
    local var_value="${!var_name}"
    if [[ "${var_value}" == *"%0A"* || "${var_value}" == *"%0D"* ]]; then
      echo "::error::Sadly, Github Action Runner unescapes '%0A' and '%0D' but does not unescape '%25'. You cannot contain '%0A' or '%0D' in the string" >&2
      exit 1
    fi
    # var_value="${var_value//%/%25}"
    var_value="${var_value//$'\n'/%0A}"
    var_value="${var_value//$'\r'/%0D}"
    echo "::set-env name=${var_name}::${var_value}"
  done
}

_set_env_prefix() {
  for var_name_prefix in "$@" ; do
    eval '_set_env "${!'"${var_name_prefix}"'@}"'
  done
}

_escape_search_regex() {
  sed -e 's/[]\/$*.^[]/\\&/g' <<<"${1}"
}

_extract_opt_from_string() {
  local opt_name="${1}"
  local opt_source_string="${2}"
  local opt_default="${3}"
  local opt_name_escaped
  opt_name_escaped="$(_escape_search_regex "${opt_name}")"
  local opt_parameter
  opt_parameter="$(set +eo pipefail ; grep -m 1 -oE '#'"${opt_name_escaped}"'(?:=(.*?))?#' <<<"${opt_source_string}" | head -n 1 ; true)"
  local opt_value
  if [ -n "${opt_parameter}" ]; then
    opt_value="$(sed -En 's/#'"${opt_name_escaped}"'(=.*)?#/\1/p' <<<"${opt_parameter}")"
    if [ -n "${opt_value}" ]; then
    opt_value="${opt_value#=}"
    else
    opt_value="${opt_default}"
    fi
  else
    opt_value="${opt_default}"
  fi
  echo -n "${opt_value}"
}

_get_opt() {
  local opt_name="${1}"
  opt_name="$(tr '[:upper:]' '[:lower:]' <<<"${opt_name}")"
  local opt_default="${2:-0}"
  local opt_value
  if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
    local commit_message
    commit_message="$(jq -crMe ".event.head_commit.message" <<<"${GITHUB_CONTEXT}")"
    opt_value="$(_extract_opt_from_string "${opt_name}" "${commit_message}" "${opt_default}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ]; then
    opt_value="$(jq -crM ".event.client_payload.${opt_name} // "'"'"${opt_default}"'"' <<<"${GITHUB_CONTEXT}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
    opt_value="$(jq -crM ".event.deployment.payload.${opt_name} // "'"'"${opt_default}"'"' <<<"${GITHUB_CONTEXT}")"
  else
    opt_value="${opt_default}"
  fi
  echo -n "${opt_value}"
}

_load_opt() {
  local opt_name="${1}"
  local opt_default="${2:-0}"
  local opt_name_upper
  local opt_name_lower
  opt_name_upper="$(echo -n "${opt_name}" | tr '[:lower:]' '[:upper:]')"
  opt_name_lower="$(echo -n "${opt_name}" | tr '[:upper:]' '[:lower:]')"
  local ENV_OPT_NAME="OPT_${opt_name_upper}"
  eval "${ENV_OPT_NAME}='$(_get_opt "${opt_name_lower}" "${opt_default}")'"
  _set_env "${ENV_OPT_NAME}"
  _append_docker_exec_env "${ENV_OPT_NAME}"
}

_append_docker_exec_env() {
  for env_name in "$@"; do
    DK_EXEC_ENVS="${DK_EXEC_ENVS} ${env_name}"
  done
  DK_EXEC_ENVS="$(tr ' ' '\n' <<< "${DK_EXEC_ENVS}" | sort -u | tr '\n' ' ')"
  _set_env DK_EXEC_ENVS
}

_source_vars() {
  local source_file="${1}"; shift
  local source_vars=( "$@" )
  # shellcheck disable=SC1090
  eval "$(source "${source_file}"; for var_name in "${source_vars[@]}"; do echo "if [ -n '${!var_name}' ]; then ${var_name}='${!var_name}' ; fi"; done )"
}