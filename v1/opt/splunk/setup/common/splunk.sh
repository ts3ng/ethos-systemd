#!/usr/bin/bash -x
source /etc/environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/lib/helpers.sh
SPLUNK_FORWARD_SERVER_LIST=$(etcd-get /splunk/SPLUNK_FORWARD_SERVER_LIST)
SPLUNK_SSLPASSWORD=$(etcd-get /splunk/SPLUNK_SSLPASSWORD)
SPLUNK_DIR="/opt/splunk/etc/system/local"

#create splunk configuration directory
mkdir -p $SPLUNK_DIR
#generate/fetch secure certs in configurations directory
sudo echo -n "$(etcd-get /splunk/SPLUNK_ADOBECAAS_CERT | awk '{gsub(/\\n/,"\n")}1')" > $SPLUNK_DIR/test_adobeacaas_cert
sudo echo -n "$(etcd-get /splunk/SPLUNK_CA | awk '{gsub(/\\n/,"\n")}1')" > $SPLUNK_DIR/test_splunk_ca

#generate configurtion outputs file
sudo echo "[tcpout]
defaultGroup = splunkssl-genericForwarder
maxQueueSize = 7MB
useACK = true
autoLB = true


[tcpout:splunkssl-genericForwarder]
server = $SPLUNK_FORWARD_SERVER_LIST
sslCertPath = /opt/splunk/etc/system/local/genericForwarder.pem
sslRootCAPath = /opt/splunk/etc/system/local/adobecaas.crt
sslPassword = $SPLUNK_SSLPASSWORD
sslVerifyServerCert = false" > $SPLUNK_DIR/outputs.conf
