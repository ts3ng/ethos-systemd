#!/bin/bash -x

source /etc/environment

if [ "$NODE_ROLE" != "proxy" ]; then
    exit 0
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../lib/helpers.sh

echo "-------Beginning proxy setup-------"

PROXY_SETUP_IMAGE=$(etcd-get /images/proxy-setup)

docker run \
    --name mesos-proxy-setup \
    --net='host' \
    --privileged \
    ${PROXY_SETUP_IMAGE}

echo "-------Done proxy setup-------"
