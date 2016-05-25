#!/usr/bin/bash -x

HOMEDIR=$(eval echo "~`whoami`")
OWNER=$(whoami)

source /etc/environment

echo "-------Beginning local credentials setup-------"

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
