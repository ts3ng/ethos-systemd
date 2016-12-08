#!/usr/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../lib/helpers.sh

IMAGE=$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /images/flight-director)

#only set Aqua endpoints for FD if Aqua is enabled
if [[ "$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /environment/services)" == *"aqua"* ]]
then
  AQUA_URL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /aqua/config/gateway-external`
  uri_parser $AQUA_URL

  AQUA_PROTOCOL=$uri_schema
  AQUA_ENDPOINT=$uri_address
  AQUA_USER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /aqua/config/user`
  AQUA_PASSWORD=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /aqua/config/password`
else
  AQUA_ENDPOINT=""
fi


/usr/bin/docker run \
  --name flight-director \
  --net='host' \
  -e LOG_APP_NAME=flight-director \
  -e FD_API_SERVER_PORT=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/api-server-port` \
  -e FD_CHRONOS_MASTER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/chronos-master` \
  -e FD_DB_DATABASE=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/db-name` \
  -e FD_DB_ENGINE=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/db-engine` \
  -e FD_DB_PASSWORD=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /environment/RDSPASSWORD` \
  -e FD_DB_PATH=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/db-path` \
  -e FD_DB_USERNAME=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/db-username` \
  -e FD_MARATHON_USER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /marathon/config/username` \
  -e FD_MARATHON_PASSWORD=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /marathon/config/password` \
  -e FD_DEBUG=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/debug` \
  -e FD_DOCKERCFG_LOCATION=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/dockercfg-location` \
  -e FD_EVENT_INTERFACE=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/event-interface` \
  -e FD_EVENT_PORT=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/event-port` \
  -e FD_FIXTURES=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/fixtures` \
  -e FD_KV_SERVER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/kv-server` \
  -e FD_LOG_LEVEL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/log-level` \
  -e FD_LOG_LOCATION=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/log-location` \
  -e FD_LOG_MARATHON_API_CALLS=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/log-marathon-api-calls` \
  -e FD_MARATHON_MASTER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/marathon-master` \
  -e FD_MESOS_MASTER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/mesos-master` \
  -e AUTHORIZER_TYPE=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/authorizer-type` \
  -e FD_AIRLOCK_PUBLIC_KEY_WHITELISTED_HOSTS=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/airlock-key-location-whitelist` \
  -e FD_IAMROLE_LABEL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/iam-role-label` \
  -e FD_AIRLOCK_PUBLIC_KEY="`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/airlock-public-key`" \
  -e FD_MARATHON_MASTER_PROTOCOL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/marathon-master-protocol` \
  -e FD_MESOS_MASTER_PROTOCOL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/mesos-master-protocol` \
  -e FD_ALLOW_MARATHON_UNVERIFIED_TLS=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/allow-marathon-unverified-tls` \
  -e FD_SCALER_PROTOCOL=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/scaler-protocol` \
  -e FD_SCALER_ENDPOINT=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/scaler-endpoint` \
  -e FD_AQUA_PROTOCOL=$AQUA_PROTOCOL \
  -e FD_AQUA_ENDPOINT=$AQUA_ENDPOINT \
  -e FD_AQUA_USER=$AQUA_USER \
  -e FD_AQUA_PASSWORD=$AQUA_PASSWORD \
  -e FD_APP_LOG_DRIVER=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/app-log-driver` \
  -e FD_ALLOW_LOG_DRIVER_TAGGING=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/allow-log-tagging` \
  -e FD_DISABLE_V1_API=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /flight-director/config/disable-v1-api` \
  $IMAGE
