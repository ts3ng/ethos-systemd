#!/usr/bin/bash -x

# TODO: possibly add a flag (NOT in etcd) so this doesn't run twice on the same machine

source /etc/environment

echo "-------Beginning Worker IAM Proxy setup-------"

if [ "${NODE_ROLE}" != "worker" ]; then
    exit 0
fi

SCRIPTDIR=$1
VERSION=$2

source ${SCRIPTDIR}/${VERSION}/lib/helpers.sh

docker pull "index.docker.io/behance/iam-docker:v1.0.0"

export NETWORK="bridge"
export GATEWAY="$(ifconfig docker0 | grep "inet " | awk -F: '{print $1}' | awk '{print $2}')"
export INTERFACE="docker0"

# These will not work until Docker > 1.9 is running
#export GATEWAY="$(docker network inspect "$NETWORK" | grep Gateway | cut -d '"' -f 4)"
#export INTERFACE="br-$(docker network inspect "$NETWORK" | grep Id | cut -d '"' -f 4 | head -c 12)"

sudo iptables -t nat -I PREROUTING -p tcp -d 169.254.169.254 --dport 80 -j DNAT --to-destination "$GATEWAY":8080 -i "$INTERFACE"

submit-fleet-unit "${SCRIPTDIR}/${VERSION}/util-units/iam-proxy.service"
start-fleet-unit "iam-proxy.service"

# Wait until service is active
until [ "`/usr/bin/docker inspect -f {{.State.Running}} iam-proxy`" == "true" ]; do
	echo "Waiting for iam-proxy service..."
    sleep 5;
done;

echo "-------Done Worker IAM Proxy setup-------"
