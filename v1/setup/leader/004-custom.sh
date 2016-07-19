#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../../lib/helpers.sh

echo "-------Leader node, beginning writing custom values to etcd-------"

DL_TABLE="sudo docker run --rm behance/docker-aws-secrets-downloader --table $SECRETS_TABLE"
# Get all available secrets and configs
AV_SECRETS=$($DL_TABLE --key secrets)
AV_CONFIGS=$($DL_TABLE --key configs)

echo "$AV_SECRETS" | while read line ; do
    SECRET=$($DL_TABLE --key secrets --name $line)
    SECRET_TYPE=`echo $SECRET | cut -d' ' -f2`
    SECRET_PATH=`echo $SECRET | cut -d' ' -f3`
    SECRET_VAL=`echo $SECRET | cut -d' ' -f4-`

    if [[ "$SECRET_TYPE" != "etcd" ]]; then
        continue
    fi

    etcd-set -- $SECRET_PATH "$SECRET_VAL"
done

echo "$AV_CONFIGS" | while read line ; do
    CONFIG=$($DL_TABLE --key configs --name $line)
    CONFIG_PATH=`echo $CONFIG | cut -d' ' -f1`
    CONFIG_VAL=`echo $CONFIG | cut -d' ' -f2-`

    etcd-set -- $CONFIG_PATH "$CONFIG_VAL"
done

# Create a dockercfg in etcd
DOCKERCFG_CONTENTS=$($DL_TABLE --key secrets --name DOCKERCFG --format plain)
etcd-set -- /docker/config/dockercfg "$DOCKERCFG_CONTENTS"

# Set the RDS Password
RDSPASSWORD=$($DL_TABLE --key secrets --name RDSPASSWORD --format plain)
etcd-set -- /environment/RDSPASSWORD "$RDSPASSWORD"

echo "-------Leader node, done writing custom values to etcd-------"
