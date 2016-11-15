#!/bin/bash -x

source /etc/environment

# Source the etcd
if [ -f /etc/profile.d/etcdctl.sh ]; then
  source /etc/profile.d/etcdctl.sh;
fi

ROLE_NAME="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /klam-ssh/config/role-name)"
ENCRYPTION_ID="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /klam-ssh/config/encryption-id)"
ENCRYPTION_KEY="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /klam-ssh/config/encryption-key)"
KEY_LOCATION_PREFIX="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /klam-ssh/config/key-location-prefix)"
IMAGE="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /images/klam-ssh)"

docker run --net=host --rm -e ROLE_NAME=${ROLE_NAME} -e ENCRYPTION_ID=${ENCRYPTION_ID} -e ENCRYPTION_KEY=${ENCRYPTION_KEY} -e KEY_LOCATION_PREFIX=${KEY_LOCATION_PREFIX} ${IMAGE} /usr/lib/klam/downloadS3.py
exit 0
