#!/usr/bin/bash -x

# Check if aqua is installed as optional service

if [[ $(etcdctl get /environment/services |grep aqua) != *aqua* ]]; then   exit 0; fi

# Check if aqua agent is healthy

ERR=1 # or some non zero error number you want
MAX_TRIES=50
COUNT=0
while [  $COUNT -lt $MAX_TRIES ]; do
   sudo docker stop aquasec-agent- 2>&1| grep -m 1 "Unauthorized"  && break
   if [ $? -eq 0 ];then
       exit 0
   fi
   let COUNT=COUNT+1 && sleep 6
done
echo "Too many tries for aqua agent service"
exit $ERR
