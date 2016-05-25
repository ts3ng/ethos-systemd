#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../helpers.sh

echo "-------Leader node, beginning writing environment variables to etcd-------"

ENV_FILE="/etc/environment"
ETCD_PREFIX="/environment"
IGNORED='^NODE|^COREOS|^#|^FLIGHT_DIRECTOR|^CAPCOM'

for line in $(cat $ENV_FILE|egrep -v $IGNORED); do
    key=${line%=*}
    value=${line#*=}

    etcdkey="$ETCD_PREFIX/$key"
    etcd-set $etcdkey $value
done

echo "-------Leader node, done writing environment variables to etcd-------"
