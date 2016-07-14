#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../lib/helpers.sh
source /etc/environment

echo "-------Leader node, beginning optional setup scripts-------"

IMAGE=$(etcd-get /images/secrets-downloader)
docker pull $IMAGE

SERVICES_OVERRIDE=$(sudo docker run --rm behance/docker-aws-secrets-downloader --table $SECRETS_TABLE --key configs | grep /environment/services)

if [[ ! -z $SERVICES_OVERRIDE ]]; then
	SERVICES=$(sudo docker run --rm behance/docker-aws-secrets-downloader --table $SECRETS_TABLE --key configs --name /environment/services)

	CONFIG_PATH=`echo $SERVICES | cut -d' ' -f1`
	CONFIG_VAL=`echo $SERVICES | cut -d' ' -f2-`

	etcd-set -- $CONFIG_PATH "$CONFIG_VAL"
fi

for service in $(etcd-get /environment/services)
do
  servicedir=$DIR/../../opt/${service}/setup/leader
  if [[ ! -d $servicedir ]]; then
      continue
  fi

  for script in $(ls $servicedir|grep -e '.sh$')
  do
      sudo $servicedir/${script}
  done
done
echo "-------Leader node, done optional setup scripts-------"
