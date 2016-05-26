#!/usr/bin/bash -x

HOMEDIR=$(eval echo "~`whoami`")
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OWNER=$(whoami)

source /etc/environment
source $DIR/../helpers.sh

echo "-------Beginning local credentials setup-------"

# Get the docker config from etcd
DOCKERCFG_CONTENTS=$(etcd-get /docker/config/dockercfg)

echo "$DOCKERCFG_CONTENTS" > /home/${OWNER}/.dockercfg
sudo chown -R ${OWNER}:${OWNER} /home/${OWNER}/.dockercfg
sudo cp /home/${OWNER}/.dockercfg /root/.dockercfg

# Actually generate a private key
if [[ ! -f ${HOMEDIR}/.ssh/id_rsa ]]; then
	ssh-keygen -f ${HOMEDIR}/.ssh/id_rsa -t rsa -N ''
fi

# ensure that we have a public key for our RSA key and that it's authorized
ssh-keygen -f ${HOMEDIR}/.ssh/id_rsa -y > ${HOMEDIR}/.ssh/id_rsa.pub
cat ${HOMEDIR}/.ssh/id_rsa.pub >> ${HOMEDIR}/.ssh/authorized_keys

# ignore requests against github.com
# TODO: maybe...re-evaluate this
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" > ${HOMEDIR}/.ssh/config

echo "-------Done local credentials setup-------"
