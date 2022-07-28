#!/bin/bash

containers="$(docker ps -a | grep -E 'builder-[0-9a-f]{20}$' | cut -d' ' -f1)"
docker rm -f ${containers}
