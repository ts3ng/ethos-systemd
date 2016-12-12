#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../../lib/helpers.sh

echo "-------Leader node, beginning writing all default values to etcd-------"

######################
#     IMAGES
######################

# TODO: this overloads the machine

etcd-set /images/secrets-downloader     "index.docker.io/behance/docker-aws-secrets-downloader:v1.1.0"
etcd-set /images/klam-ssh               "index.docker.io/behance/klam-ssh:v1"

etcd-set /images/chronos                "index.docker.io/mesosphere/chronos:chronos-2.5.0-0.1.20160824153434.ubuntu1404-mesos-1.0.0"
etcd-set /images/flight-director        "index.docker.io/behance/flight-director:dc5b9901bedd873d37513e11a85224afdb1ba584"
etcd-set /images/marathon               "index.docker.io/mesosphere/marathon:v1.3.0"
etcd-set /images/mesos-master           "index.docker.io/mesosphere/mesos-master:1.0.1-2.0.93.ubuntu1404"
etcd-set /images/zk-exhibitor           "index.docker.io/behance/docker-zk-exhibitor:v1.0.0"
etcd-set /images/cfn-signal             "index.docker.io/behance/docker-cfn-bootstrap:v1.0.0"
etcd-set /images/jenkins                "index.docker.io/jenkins:1.651.1"
etcd-set /images/booster                "index.docker.io/behance/booster:0.7"
etcd-set /images/booster-sidekick       "index.docker.io/behance/booster-sidekick:0.3"

etcd-set /images/capcom                 "index.docker.io/behance/capcom:55472229a28c118a4bd1e3f98e44ed8fac24350c"
etcd-set /images/proxy                  "index.docker.io/nginx:1.9.5"
etcd-set /images/control-proxy          "index.docker.io/behance/apigateway:v0.0.2"

etcd-set /images/mesos-slave            "index.docker.io/mesosphere/mesos-slave:1.0.1-2.0.93.ubuntu1404"

etcd-set /images/etcd-locks              "index.docker.io/adobeplatform/etcd-locks:v0.1"

######################
#      CAPCOM
######################

etcd-set /bootstrap.service/capcom              true
etcd-set /capcom/config/applications            '[]'
etcd-set /capcom/config/host                    127.0.0.1
etcd-set /capcom/config/db-path                 ./capcom.db
etcd-set /capcom/config/kv-store-server-address http://$ETCDCTL_ROOT_USER:$ETCDCTL_ROOT_PASSWORD@$CAPCOM_KV_ENDPOINT
etcd-set /capcom/config/kv-ttl                  10
etcd-set /capcom/config/log-level               "info"
etcd-set /capcom/config/log-location            "stdout"
etcd-set /capcom/config/port                    2002
etcd-set /capcom/config/proxy                   nginx
etcd-set /capcom/config/proxy-config-file       /etc/nginx/nginx.conf
etcd-set /capcom/config/proxy-enabled           true
etcd-set /capcom/config/proxy-restart-script    /restart_nginx_docker.sh
etcd-set /capcom/config/proxy-timeout           65000
etcd-set /capcom/config/proxy-docker-command    "nginx -g 'daemon off;'"
etcd-set /capcom/config/ssl-cert-location       ""


######################
#  FLIGHT DIRECTOR
######################

etcd-set /bootstrap.service/flight-director true
etcd-set /flight-director/config/api-server-port 2001
etcd-set /flight-director/config/chronos-master "$FLIGHT_DIRECTOR_CHRONOS_ENDPOINT"
etcd-set /flight-director/config/db-name "$FLIGHT_DIRECTOR_DB_NAME"
etcd-set /flight-director/config/db-engine mysql
etcd-set /flight-director/config/db-path "$FLIGHT_DIRECTOR_DB_PATH"
etcd-set /flight-director/config/db-username "$FLIGHT_DIRECTOR_DB_USERNAME"
etcd-set /flight-director/config/dockercfg-location file:///root/.dockercfg
etcd-set /flight-director/config/debug false
etcd-set /flight-director/config/event-interface ''
etcd-set /flight-director/config/event-port 2001
etcd-set /flight-director/config/fixtures "prod"
etcd-set /flight-director/config/kv-server http://$ETCDCTL_ROOT_USER:$ETCDCTL_ROOT_PASSWORD@localhost:2379
etcd-set /flight-director/config/log-level "info"
etcd-set /flight-director/config/log-location "stdout"
etcd-set /flight-director/config/log-marathon-api-calls false
etcd-set /flight-director/config/marathon-master "$FLIGHT_DIRECTOR_MARATHON_ENDPOINT"
# etcd-set /flight-director/config/mesos-master "$FLIGHT_DIRECTOR_MESOS_ENDPOINT"
etcd-set /flight-director/config/mesos-master localhost:5050
etcd-set /flight-director/config/marathon-master-protocol http
etcd-set /flight-director/config/allow-marathon-unverified-tls false
etcd-set /flight-director/config/mesos-master-protocol http
etcd-set /flight-director/config/authorizer-type airlock
etcd-set /flight-director/config/airlock-key-location-whitelist be-moonbeam-qe.s3.amazonaws.com
etcd-set /flight-director/config/iam-role-label com.swipely.iam-docker.iam-profile
etcd-set /flight-director/config/scaler-protocol http
etcd-set /flight-director/config/scaler-endpoint localhost:2042
#This needs to be false for Docker < 1.11. Change to true for newer clusters
etcd-set /flight-director/config/allow-log-tagging false
etcd-set /flight-director/config/disable-v1-api false
etcd-set /flight-director/config/app-log-driver journald

######################
#     ZOOKEEPER
######################

etcd-set /bootstrap.service/zookeeper true

etcd-set /zookeeper/config/exhibitor/s3-prefix  "zk"
etcd-set /zookeeper/config/exhibitor/s3-bucket  $EXHIBITOR_S3BUCKET
etcd-set /zookeeper/config/ensemble-size        $CONTROL_CLUSTER_SIZE
etcd-set /zookeeper/config/endpoint             $ZOOKEEPER_ENDPOINT
etcd-set /zookeeper/config/username             "zk"
etcd-set /zookeeper/config/password             "password"


######################
#        MESOS
######################

etcd-set /mesos/config/username ethos

######################
#       BOOSTER
######################

etcd-set /booster/config/nopersistence 1
etcd-set /booster/nodes ","

######################
#      SERVICES
######################

etcd-set /environment/services "sumologic datadog"

######################
#      skopos
######################
source $DIR/../../lib/lock_helpers.sh

# effects number of simulataneous lock holder per-tier for coreos updates
etcd-set /adobe.com/settings/etcd-locks/coreos_reboot/num_worker 1
etcd-set /adobe.com/settings/etcd-locks/coreos_reboot/num_control 1
etcd-set /adobe.com/settings/etcd-locks/coreos_reboot/num_proxy 1

#
etcd-set /adobe.com/settings/etcd-locks/coreos_drain/num_worker 1
etcd-set /adobe.com/settings/etcd-locks/coreos_drain/num_control 1
etcd-set /adobe.com/settings/etcd-locks/coreos_drain/num_proxy 1

#
etcd-set /adobe.com/settings/etcd-locks/booster_drain/num_worker 1
etcd-set /adobe.com/settings/etcd-locks/booster_drain/num_control 1
etcd-set /adobe.com/settings/etcd-locks/booster_drain/num_proxy 1



echo "-------Leader node, done writing all default values to etcd-------"
