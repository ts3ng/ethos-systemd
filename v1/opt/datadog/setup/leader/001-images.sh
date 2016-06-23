#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/dd-agent               "index.docker.io/behance/docker-dd-agent:latest"
etcd-set /images/dd-agent-mesos         "index.docker.io/behance/docker-dd-agent-mesos:latest"
etcd-set /images/dd-agent-mesos-master  "index.docker.io/adobeplatform/docker-dd-agent-mesos-master:latest"
etcd-set /images/dd-agent-mesos-slave   "index.docker.io/adobeplatform/docker-dd-agent-mesos-slave:latest"
etcd-set /images/dd-agent-proxy         "index.docker.io/behance/docker-dd-agent-proxy:latest"
