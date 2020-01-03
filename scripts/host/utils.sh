#!/bin/bash

_check_missing_vars() {
    declare -a missing_vars
    for var_name in $@ ; do
        if [ -z "${!var_name}" ]; then
            missing_vars+=( ${var_name} )
        fi
    done
    echo -n "${missing_vars[@]}"
}

_set_env() {
    for var_name in $@ ; do
        echo "::set-env name=${var_name}::${!var_name}"
    done
}

_set_env_prefix() {
    for var_name_prefix in $@ ; do
        eval '_set_env ${!'"${var_name_prefix}"'@}'
    done
}
