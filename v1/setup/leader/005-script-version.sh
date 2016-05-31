#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../../lib/helpers.sh

# This does not use the helper because it sometimes expects a 4 response
etcdctl get /environment/SCRIPTS-FORK

if [[ $? = 4 ]]; then
  # 4 == 404 - key not found
  # case where a node is joining a pre-existing cluster
  SCRIPTS_REV=$(cd $DIR/../../../ && git rev-parse HEAD)
  etcd-set /environment/SCRIPTS-FORK adobe-platform
  etcd-set /environment/SCRIPTS-SHA  $SCRIPTS_REV
fi
