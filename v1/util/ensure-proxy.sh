#!/usr/bin/bash -x

source /etc/profile.d/etcdctl.sh
source /etc/environment
PROXY=$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /capcom/config/proxy)

if [ -f /etc/$PROXY/nginx.conf ]; then exit 0; fi

if [ ! -d /etc/$PROXY ]; then
	sudo mkdir -p /etc/$PROXY;
fi

sudo cat << EOT >> /etc/$PROXY/nginx.conf
events { worker_connections  1024;  }
EOT

exit 0
