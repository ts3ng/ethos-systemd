#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/scalock-gateway    "index.docker.io/behance/scalock-gateway:1.2.tp2"
etcd-set /images/scalock-agent      "index.docker.io/behance/scalock-agent:1.2.tp1"
etcd-set /images/scalock-server     "index.docker.io/behance/scalock-server:1.2.tp1"
