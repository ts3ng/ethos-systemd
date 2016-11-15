
#!/usr/bin/bash

# This file will read from etcd with credentials
source /etc/environment

if [[ "$1" = "get" ]]; then
  etcdctl -u $ETCDCTL_READ_USER:$ETCDCTL_READ_PASSWORD "$@"
elif [[ "$1" = "set" ]]; then
  etcdctl -u $ETCDCTL_WRITE_USER:$ETCDCTL_WRITE_PASSWORD "$@"
else
  etcdctl -u $ETCDCTL_ROOT_USER:$ETCDCTL_ROOT_PASSWORD "$@"
fi
