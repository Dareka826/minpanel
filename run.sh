#!/bin/sh

DIR="$(dirname "$(readlink -f "${0}")")"

exec env \
    -i \
    PATH="${PATH}" \
    LD_PRELOAD="${LD_PRELOAD}" \
        busybox httpd \
            -f \
            -v \
            -p 127.0.0.1:8000 \
            -h "${DIR}/data" \
            -c "${DIR}/httpd.conf"
