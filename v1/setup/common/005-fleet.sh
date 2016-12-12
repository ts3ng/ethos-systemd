#!/bin/bash -x

source /etc/environment

echo "-------Beginning Fleet config setup-------"

CONF_DIR=/run/systemd/system/fleet.service.d
if [ ! -d $CONF_DIR ]; then
    sudo mkdir $CONF_DIR
fi

# https://gist.github.com/skippy/d539442ada90be06459c
# TODO: discuss anything else that would be useful here
if [[ -z $ZONE ]]; then
	AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
fi
REGION=${AZ::-1}

METADATA="FLEET_METADATA=region=${REGION},az=${AZ},role=${NODE_ROLE},ip=${COREOS_PRIVATE_IPV4}"
sudo echo -e "[Service]\nEnvironment='${METADATA}'" > $CONF_DIR/21-aws.conf

CRED_DIR="/opt/fleet"
if [[ ! -d $CRED_DIR ]]; then
    sudo mkdir $CRED_DIR -p
fi

DROPIN_FILE=$CRED_DIR/fleet.env
sudo cat > $DROPIN_FILE <<EOF
FLEET_ETCD_USERNAME=$ETCDCTL_ROOT_USER
FLEET_ETCD_PASSWORD=$ETCDCTL_ROOT_PASSWORD
EOF

sudo chmod 0600 $CRED_DIR/fleet.env
sudo chown -R $(whoami):$(whoami) $CRED_DIR

sudo cp /usr/lib64/systemd/system/fleet.service /etc/systemd/system/fleet.service

sudo sed -i "14i EnvironmentFile=/etc/environment" /etc/systemd/system/fleet.service
sudo sed -i '15i Environment="FLEET_ETCD_SERVERS=http://0.0.0.0:2379"' /etc/systemd/system/fleet.service
sudo sed -i "16i EnvironmentFile=-/opt/fleet/fleet.env" /etc/systemd/system/fleet.service

sudo systemctl daemon-reload
sudo systemctl restart fleet

sleep 5

echo "-------Done Fleet config setup-------"
