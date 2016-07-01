#!/bin/bash 
source /etc/environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh 
SPLUNK_FORWARD_SERVER_LIST=$(etcd-get /splunk/config/forward-server-list)
SPLUNK_SSLPASSWORD=$(etcd-get /splunk/config/sslpassword)
SPLUNK_DIR="/opt/splunk/etc/system/local"

#create splunk configuration directory
mkdir -p $SPLUNK_DIR
#generate/fetch secure certs in configurations directory
cat << EOF > /$SPLUNK_DIR/adobecaas.crt
$(etcd-get /splunk/config/adobecaas-cert | awk '{gsub(/\\n/,"\n")}1')
EOF

cat << EOF > /$SPLUNK_DIR/genericForwarder.pem
$(etcd-get /splunk/config/ca-cert | awk '{gsub(/\\n/,"\n")}1')
EOF

#generate configurtion outputs file
cat << EOF > /$SPLUNK_DIR/outputs.conf
[tcpout]
defaultGroup = splunkssl-genericForwarder
maxQueueSize = 7MB
useACK = true
autoLB = true


[tcpout:splunkssl-genericForwarder]
server = $SPLUNK_FORWARD_SERVER_LIST
sslCertPath = /opt/splunk/etc/system/local/genericForwarder.pem
sslRootCAPath = /opt/splunk/etc/system/local/adobecaas.crt
sslPassword = $SPLUNK_SSLPASSWORD
sslVerifyServerCert = false
EOF
