#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/ecr-login "index.docker.io/behance/ecr-login:43914496184150bd476f88b6832c24300089b46d_20161009"
