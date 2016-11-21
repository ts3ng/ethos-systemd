#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/scalock-gateway    "index.docker.io/aquasec/gateway:1.2.3"
etcd-set /images/scalock-agent      "index.docker.io/behance/aquasec-agent:timeout"
etcd-set /images/scalock-server     "index.docker.io/aquasec/server:1.2.3"
