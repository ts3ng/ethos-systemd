#!/usr/bin/bash -x

source /etc/environment

if [ ! -f /etc/systemd/system/docker.socket ]; then
    sudo cp /usr/lib64/systemd/system/docker.socket /etc/systemd/system/docker.socket
fi
