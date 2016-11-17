#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/dd-agent               "index.docker.io/behance/docker-dd-agent:v1.0.0"
etcd-set /images/dd-agent-mesos         "index.docker.io/behance/docker-dd-agent-mesos:v1.0.0"
etcd-set /images/dd-agent-mesos-master  "index.docker.io/adobeplatform/docker-dd-agent-mesos-master:v1.0.0"
etcd-set /images/dd-agent-mesos-slave   "index.docker.io/adobeplatform/docker-dd-agent-mesos-slave:v1.0.0"
etcd-set /images/dd-agent-proxy         "index.docker.io/behance/docker-dd-agent-proxy:v1.0.0"

# TODO: remove the keys above as they are not needed anymore
etcd-set /images/ethos-dd-agent         "index.docker.io/adobeplatform/ethos-dd-agent:v1.0"