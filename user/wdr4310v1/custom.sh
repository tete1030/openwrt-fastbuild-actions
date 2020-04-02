#!/bin/bash

echo "=============================================="
echo "Removing all 616-net_optimize_xfrm_calls.patch"
find target/linux/generic/ -path 'target/linux/generic/pending-*/616-net_optimize_xfrm_calls.patch' -print -exec rm {} \;
echo "=============================================="
