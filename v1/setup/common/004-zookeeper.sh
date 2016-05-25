#!/bin/bash -x

source /etc/environment

if [ "${NODE_ROLE}" != "control" ]; then
    exit 0
fi

echo "-------Beginning Zookeeper config setup-------"

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sudo cp $SCRIPTDIR/../../util-units/zk-health.service /etc/systemd/system/zk-health.service

# This will be run in the next script, no use doing it twice
#sudo systemctl daemon-reload

echo "-------Done Zookeeper config setup-------"
