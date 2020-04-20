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

_escape_search_regex() {
  sed -e 's/[]\/$*.^[]/\\&/g' <<<"${1}"
}

_extract_opt_from_string() {
  local opt_name="${1}"
  local opt_source_string="${2}"
  local opt_default="${3}"
  local opt_default_present="${4}"
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
      opt_value="${opt_default_present}"
    fi
  else
    opt_value="${opt_default}"
  fi
  echo -n "${opt_value}"
}

_source_vars() {
  local source_file="${1}"; shift
  local source_vars=( "$@" )
  # shellcheck disable=SC1090
  eval "$(source "${source_file}"; for var_name in "${source_vars[@]}"; do echo "if [ -n '${!var_name}' ]; then ${var_name}='${!var_name}' ; fi"; done )"
}