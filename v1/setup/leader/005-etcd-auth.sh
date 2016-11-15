#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../../lib/helpers.sh

echo "-------Leader node, beginning etcd auth setup-------"

CRED_DIR="/opt/etcdctl"
if [[ ! -d $CRED_DIR ]]; then
    sudo mkdir $CRED_DIR -p
fi

sudo chown -R $(whoami):$(whoami) $CRED_DIR

# Add user function

function add_users (){

sudo cat << EOF > $CRED_DIR/${1}.json
{
  "user": "$1",
  "password": "$2"
}
EOF
}

# TODO: retrying of below etcd commands

add_users $ETCDCTL_ROOT_USER $ETCDCTL_ROOT_PASSWORD
add_users $ETCDCTL_READ_USER $ETCDCTL_READ_PASSWORD
add_users $ETCDCTL_WRITE_USER $ETCDCTL_WRITE_PASSWORD

# add root-user
curl -L http://127.0.0.1:2379/v2/auth/users/${ETCDCTL_ROOT_USER} -XPUT -d "@$CRED_DIR/root.json"

# add read-user
curl -L http://127.0.0.1:2379/v2/auth/users/${ETCDCTL_READ_USER} -XPUT -d "@$CRED_DIR/read-user.json"

# add write-user
curl -L http://127.0.0.1:2379/v2/auth/users/${ETCDCTL_WRITE_USER} -XPUT -d "@$CRED_DIR/write-user.json"

# read access
etcdctl role add read-only
etcdctl role grant read-only -path '/*' -read

# write access
etcdctl role add read-write
etcdctl role grant read-write -path '/*' -readwrite

# Give read-user read access
sudo echo '{"user": "'${ETCDCTL_READ_USER}'", "grant": ["read-only"], "password": "'$ETCDCTL_READ_PASSWORD'"}' > $CRED_DIR/read-only.json
curl -L http://127.0.0.1:2379/v2/auth/users/${ETCDCTL_READ_USER} -XPUT -d "@$CRED_DIR/read-only.json"

# Give read-write write access
sudo echo '{"user": "'${ETCDCTL_WRITE_USER}'", "grant": ["read-write"], "password": "'$ETCDCTL_WRITE_PASSWORD'"}' > $CRED_DIR/read-write.json
curl -L http://127.0.0.1:2379/v2/auth/users/${ETCDCTL_WRITE_USER} -XPUT -d "@$CRED_DIR/read-write.json"

# Enable authentication
etcdctl auth enable

sudo rm -rf $CRED_DIR

echo "-------Leader node, done etcd auth setup-------"
