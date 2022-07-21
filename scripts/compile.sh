#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages"
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/packages"
  echo "Dummy firmware" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/firmware.bin"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages/packages.tar.gz"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/packages/packages.tar.gz"
  exit 0
fi

save_output() {
  stdbuf -oL -eL tee /tmp/compile_output.txt
}

trickle () {
  gawk 'BEGIN { t = systime() }
              { printf("[%5d] ", systime() - t) ; print $0 ; system("") }
              { t = systime() }'
}

compile() {
  (
    cd "${OPENWRT_CUR_DIR}"
    if [ "x${MODE}" = "xm" ]; then
      local nthread=$(($(nproc) + 1)) 
      echo "${nthread} thread compile: $*"
      make -j${nthread} "$@" | save_output | trickle
    elif [ "x${MODE}" = "xs" ]; then
      echo "Fallback to single thread compile: $*"
      make -j1 V=s "$@" | save_output | trickle
    else
      echo "No MODE specified" >&2
      exit 1
    fi
  )
}

echo "Executing pre_compile.sh"
if [ -f "${BUILDER_PROFILE_DIR}/pre_compile.sh" ]; then
  /bin/bash "${BUILDER_PROFILE_DIR}/pre_compile.sh"
fi

echo "Compiling..."
set +eo pipefail
last_status=0

prev_failure_package=
if [ -f "/tmp/failed_packages.txt" ]; then
  prev_failure_package="$(cat /tmp/failed_packages.txt | head -n 1)"
  rm -f /tmp/failed_packages.txt
fi

if [ -e "${prev_failure_package}" ]; then
  if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
    compile
    last_status=$?
  else
    compile "package/compile"
    last_status=$?
    if [ $last_status -eq 0 ]; then
      compile "package/index"
      last_status=$?
    fi
  fi
else
  echo "Compiling only previously failed package: ${prev_failure_package}"
  compile "${prev_failure_package}"
  last_status=$?
fi

if [ $last_status -ne 0 ]; then
  echo "::error::Compile has failed" >&2
  echo -n "::error::" >&2
  grep -i "error:" /tmp/compile_output.txt >&2

  # ERROR: package/feeds/packages/qemu failed to build.
  re='ERROR:\s+([^\s]+)\s+failed to build'
  if grep -P "$re" -o /tmp/compile_output.txt >/dev/null ; then
    echo "::error::Failed packages:" >&2
    grep -P "$re" -o /tmp/compile_output.txt | tr -s ' ' |  cut -d ' ' -f2 | tee /tmp/failed_packages.txt >&2
  else
    if [ -f "/tmp/failed_packages.txt" ]; then
      rm -f /tmp/failed_packages.txt
    fi
  fi
fi
