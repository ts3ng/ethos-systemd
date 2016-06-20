#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../../lib/helpers.sh

exit 0

echo "-------Leader node, beginning etcd auth setup-------"

etcd-set /etcdctl/config/root-user root
etcd-set /etcdctl/config/read-user read-user
etcd-set /etcdctl/config/write-user write-user

ROOT_USERNAME=$(etcd-get /etcdctl/config/root-user)
ROOT_PASSWORD=$(etcd-get /etcdctl/config/root-password)
READ_USERNAME=$(etcd-get /etcdctl/config/read-user)
READ_PASSWORD=$(etcd-get /etcdctl/config/read-password)
WRITE_USERNAME=$(etcd-get /etcdctl/config/write-user)
WRITE_PASSWORD=$(etcd-get /etcdctl/config/write-password)

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

add_users $ROOT_USERNAME $ROOT_PASSWORD
add_users $READ_USERNAME $READ_PASSWORD
add_users $WRITE_USERNAME $WRITE_PASSWORD

# add root-user
curl -L http://127.0.0.1:2379/v2/auth/users/${ROOT_USERNAME} -XPUT -d "@$CRED_DIR/root.json"

# add read-user
curl -L http://127.0.0.1:2379/v2/auth/users/${READ_USERNAME} -XPUT -d "@$CRED_DIR/read-user.json"

# add write-user
curl -L http://127.0.0.1:2379/v2/auth/users/${WRITE_USERNAME} -XPUT -d "@$CRED_DIR/write-user.json"

# read access
etcdctl role add read-only
etcdctl role grant read-only -path '/*' -read

# write access
etcdctl role add read-write
etcdctl role grant read-write -path '/*' -readwrite

# Give read-user read access
sudo echo '{"user": "'${READ_USERNAME}'", "grant": ["read-only"]}' > $CRED_DIR/read-only.json
curl -L http://127.0.0.1:2379/v2/auth/users/${READ_USERNAME} -XPUT -d "@$CRED_DIR/read-only.json"

# Give read-write write access
sudo echo '{"user": "'${WRITE_USERNAME}'", "grant": ["read-write"]}' > $CRED_DIR/read-write.json
curl -L http://127.0.0.1:2379/v2/auth/users/${WRITE_USERNAME} -XPUT -d "@$CRED_DIR/read-write.json"

# Enable authentication
etcdctl auth enable

sudo rm -rf $CRED_DIR

echo "-------Leader node, done etcd auth setup-------"
