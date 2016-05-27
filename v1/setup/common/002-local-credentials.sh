#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../../lib/helpers.sh

echo "-------Beginning local credentials setup-------"

# Get the docker config from etcd
DOCKERCFG_CONTENTS=$(etcd-get /docker/config/dockercfg)

echo "$DOCKERCFG_CONTENTS" > /home/core/.dockercfg
sudo chown -R core:core /home/core/.dockercfg
sudo cp /home/core/.dockercfg /root/.dockercfg

# Actually generate a private key
if [[ ! -f /home/core/.ssh/id_rsa ]]; then
	ssh-keygen -f /home/core/.ssh/id_rsa -t rsa -N ''
fi

# ensure that we have a public key for our RSA key and that it's authorized
ssh-keygen -f /home/core/.ssh/id_rsa -y > /home/core/.ssh/id_rsa.pub
cat /home/core/.ssh/id_rsa.pub >> /home/core/.ssh/authorized_keys

# ignore requests against github.com
# TODO: maybe...re-evaluate this
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" > /home/core/.ssh/config

echo "-------Done local credentials setup-------"
