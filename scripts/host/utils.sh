#!/bin/bash

_check_missing_vars() {
    declare -a missing_vars
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
        var_value="${!var_name}"
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
