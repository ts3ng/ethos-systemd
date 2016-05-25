#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source /etc/environment
source $DIR/../helpers.sh

echo "-------Beginning download of Docker images-------"

docker pull $(etcd-get /images/gocron-logrotate)
docker pull $(etcd-get /images/sumologic)
docker pull $(etcd-get /images/sumologic-syslog)
docker pull $(etcd-get /images/dd-agent)

if [ "${NODE_ROLE}" = "control" ]; then
    docker pull $(etcd-get /images/jenkins)
	docker pull $(etcd-get /images/dd-agent-mesos)
	docker pull $(etcd-get /images/chronos)
	docker pull $(etcd-get /images/flight-director)
	docker pull $(etcd-get /images/marathon)
	docker pull $(etcd-get /images/mesos-master)
	docker pull $(etcd-get /images/zk-exhibitor)
	docker pull $(etcd-get /images/cfn-signal)
fi

if [ "${NODE_ROLE}" = "proxy" ]; then
	export ETCDCTL_PEERS="http://$ETCDCTL_PEERS_ENDPOINT"

    docker pull $(etcd-get /images/proxy-setup)
	docker pull $(etcd-get /images/capcom)
	docker pull $(etcd-get /images/capcom2)
	docker pull $(etcd-get /images/proxy)
fi

if [ "${NODE_ROLE}" = "worker" ]; then
	export ETCDCTL_PEERS="http://$ETCDCTL_PEERS_ENDPOINT"
	
    docker pull $(etcd-get /images/mesos-slave)
fi

echo "-------Done download of Docker images-------"
