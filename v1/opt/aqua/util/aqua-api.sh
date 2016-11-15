#!/usr/bin/bash -x

source /etc/environment


SCALOCK_ADMIN_PASSWORD=$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /aqua/config/password)

# Wait for web ui to be active
WEB_ACTIVE=$(curl http://localhost:8083/api)

while [[ -z $WEB_ACTIVE ]]; do
  echo "Waiting for web UI to become active"
  WEB_ACTIVE=$(curl http://localhost:8083/api)
  sleep 5;
done

sudo curl -H "Content-Type: application/json" -u administrator:$SCALOCK_ADMIN_PASSWORD -X POST -d '{"name":"core-user rule","description": "Core User is Admin of all containers","role":"administrator","resources":{"containers":["*"],"images":["*"],"volumes":["*"],"networks":["*"]},"accessors":{"users":["core"]}}' http://localhost:8083/api/v1/adminrules

sudo curl -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"name": "Ethos", "type": "security.profile", "description": "Ethos Default RunTime Profile", "encrypt_all_envs": true}' -u administrator:$SCALOCK_ADMIN_PASSWORD http://localhost:8083/api/v1/securityprofiles

