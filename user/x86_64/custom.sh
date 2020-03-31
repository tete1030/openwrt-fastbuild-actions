#!/bin/bash

KERNEL_CONFIG_FILE="target/linux/x86/config-4.19"

if [ ! -f "${KERNEL_CONFIG_FILE}" ]; then
    echo "Kernel config file not found, config cannot be added"
    exit 1
fi

# For debug kernel & reboot problem
echo "
CONFIG_CONFIGFS_FS=m
CONFIG_NETCONSOLE=m
CONFIG_NETCONSOLE_DYNAMIC=y
CONFIG_NETPOLL=y
CONFIG_NET_POLL_CONTROLLER=y
" >> "${KERNEL_CONFIG_FILE}"

rm target/linux/generic/pending-4.9/616-net_optimize_xfrm_calls.patch
rm target/linux/generic/pending-4.14/616-net_optimize_xfrm_calls.patch
rm target/linux/generic/pending-4.19/616-net_optimize_xfrm_calls.patch

echo "Kernel config for NetConsole added"
