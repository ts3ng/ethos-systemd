#!/bin/bash -x

source /etc/environment

if [ "${NODE_ROLE}" != "control" ] && [ "${NODE_ROLE}" != "worker" ]; then
    exit 0
fi

echo "-------Beginning Mesos credentials setup-------"

source /etc/profile.d/etcdctl.sh || :

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../lib/helpers.sh

CREDS="$(etcd-get /mesos/config/username) $(etcd-get /mesos/config/password)"

CRED_DIR="/opt/mesos"
if [[ ! -d $CRED_DIR ]]; then
    sudo mkdir $CRED_DIR -p
fi

# primary credentials used by workers & masters
sudo echo "$CREDS" > $CRED_DIR/credentials

if [[ "${NODE_ROLE}" = "control" ]]; then
    # on a control node - set up credentials for registering frameworks
    # (i.e.: marathon & chronos)
    # TODO: have separate credentials for framework vs worker/master
    sudo echo -n "$CREDS" >> $CRED_DIR/credentials
    sudo echo -n "$(etcd-get /mesos/config/password)" > $CRED_DIR/framework-secret
    sudo chmod 0600 $CRED_DIR/framework-secret
fi

sudo chmod 0600 $CRED_DIR/credentials
sudo chown -R $(whoami):$(whoami) $CRED_DIR

echo "-------Done Mesos credentials setup-------"
