#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/sumologic              "index.docker.io/behance/docker-sumologic:latest"
etcd-set /images/sumologic-syslog       "index.docker.io/behance/docker-sumologic:syslog-latest"
