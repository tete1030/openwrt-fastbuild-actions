#/bin/bash

set -eo pipefail

cd openwrt
make download -j8
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;
