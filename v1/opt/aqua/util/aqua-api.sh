#!/usr/bin/bash -x

source /etc/environment


SCALOCK_ADMIN_PASSWORD=$(etcdctl get /aqua/config/password)

# Wait for web ui to be active
WEB_ACTIVE=$(curl http://localhost:8083/api)

while [[ -z $WEB_ACTIVE ]]; do
  echo "Waiting for web UI to become active"
  WEB_ACTIVE=$(curl http://localhost:8083/api)
  sleep 5;
done

sudo curl -H "Content-Type: application/json" -u administrator:$SCALOCK_ADMIN_PASSWORD -X POST -d '{"name":"core-user rule","description": "Core User is Admin of all containers","role":"administrator","resources":{"containers":["*"],"images":["*"],"volumes":["*"],"networks":["*"]},"accessors":{"users":["core"]}}' http://localhost:8083/api/v1/adminrules


sudo curl -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"name": "Ethos", "type": "security.profile", "user": "", "author": "system", "version": "1.0", "cpu_quota": {"unit": "%", "value": 0}, "allow_root": true, "allow_users": null, "description": "Ethos Default RunTime Profile", "memory_limit": {"unit": "MB", "value": 0}, "max_processes": 0, "readonly_files": null, "monitored_files": null, "allow_executables": [], "block_inbound_connections": false, "block_outbound_connections": true,"encrypt_all_envs": true}' -u administrator:$SCALOCK_ADMIN_PASSWORD http://localhost:8083/api/v1/securityprofiles
