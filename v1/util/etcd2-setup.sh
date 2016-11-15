#!/usr/bin/bash -x

source /etc/environment

# NOTE: this needs to be run with sudo privileges
# $1 must be the SCRIPTDIR; $2 must be the ethos-systemd version

echo "-------Control node found, setting up etcd peers-------"

mkdir -p /etc/systemd/system/etcd2.service.d
DROPIN_FILE=/etc/systemd/system/etcd2.service.d/30-etcd_peers.conf

cat > $DROPIN_FILE <<EOF
[Service]
# Load the other hosts in the etcd leader autoscaling group from file
EnvironmentFile=/etc/sysconfig/etcd-peers
EOF

chown root:root $DROPIN_FILE
chmod 0644 $DROPIN_FILE

# Sometimes this is needed?
systemctl daemon-reload

SCRIPTDIR=$1
VERSION=$2
cp "${SCRIPTDIR}/${VERSION}/util-units/etcd-peers.service" /etc/systemd/system/
systemctl start etcd-peers

echo "-------Waiting for etcd2 to start-------"

while [[ $(/home/core/ethos-systemd/v1/lib/etcdauth.sh cluster-health|grep unhealthy) || $(/home/core/ethos-systemd/v1/lib/etcdauth.sh member list | wc -l) -lt $CONTROL_CLUSTER_SIZE ]]
do
  sleep 8
done

echo "-------etcd2 started, continuing with bootstrapping-------"
