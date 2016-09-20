#!/usr/bin/bash -x
source /etc/environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../lib/helpers.sh

if [ "${NODE_ROLE}" != "logging" ]; then
    exit 0
fi

SPLUNK_DIR="/opt/splunk-fluentd/etc/system/local"
SPLUNK_ENABLE_CLOUDOPS_FORWARDER=$(etcd-get /splunk/config/cloudops/enable-forwarder)
SPLUNK_ENABLE_HEC_FORWARDER=$(etcd-get /splunk/config/hec/enable-forwarder)
SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST=$(etcd-get /splunk/config/cloudops/forward-server-list)
SPLUNK_CLOUDOPS_SSLPASSWORD=$(etcd-get /splunk/config/cloudops/sslpassword)
SPLUNK_CLOUDOPS_INDEX=$(etcd-get /splunk/config/cloudops/index)
SPLUNK_FORWARDER_HOST=`curl -s http://169.254.169.254/latest/meta-data/hostname`
SPLUNK_CLOUDOPS_CERTPATH_FORMAT=$(etcd-get /splunk/config/cloudops/certpath-format)
SPLUNK_CLOUDOPS_ROOTCA_FORMAT=$(etcd-get /splunk/config/cloudops/rootca-format)
SPLUNK_HEC_TOKEN=$(etcd-get /splunk/config/hec/token)
SPLUNK_HEC_ENDPOINT=$(etcd-get /splunk/config/hec/endpoint)
SPLUNK_HEC_DEFAULT_INDEX=$(etcd-get /splunk/config/hec/default-index)

#create splunk configuration directory
mkdir -p $SPLUNK_DIR

#setup inputs.conf to listen for fluentd messages, NOTE: HEC should override cloudops, you shoudl only need to send to one endpoint
DEFAULTGROUP="splunkssl"
DEFAULTINDEX=$SPLUNK_CLOUDOPS_INDEX
if [ "SPLUNK_ENABLE_HEC_FORWARDER" == "1" ]; then
	$DEFAULTGROUP="splunkhec"
	$DEFAULTINDEX=$SPLUNK_HEC_DEFAULT_INDEX
fi

cat << EOF > /$SPLUNK_DIR/inputs.conf
[tcp://9997]
index = $DEFAULTINDEX
_TCP_ROUTING = $DEFAULTGROUP
EOF

#setup props listeners
cat << EOF > /$SPLUNK_DIR/props.conf
[source::tcp:9997]
TRANSFORMS-index = default_index
TRANSFORMS-sourcetype = default_sourcetype
EOF


#setup default transforms.conf configuration this will be updated via api from marathon imagedef extraction
cat << EOF > /$SPLUNK_DIR/transforms.conf
[default_index]
REGEX = .
DEST_KEY = _MetaData:Index
FORMAT = $SPLUNK_HEC_DEFAULT_INDEX

[default_sourcetype]
REGEX = .
DEST_KEY = MetaData:Sourcetype
FORMAT = sourcetype::json

EOF

#Setup default values for outputs.conf
cat << EOF > /$SPLUNK_DIR/outputs.conf
[default]
defaultGroup = splunkssl

EOF

#Forwarding to HEC splunk indexer else use cert based cloudops endpoints
if [ "$SPLUNK_ENABLE_HEC_FORWARDER" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/outputs.com
[tcpout:splunkhec]
token = $SPLUNK_HEC_TOKEN
server = $SPLUNK_HEC_ENDPOINT
EOF

else
#Generate CloudOps Certs
cat << EOF > /$SPLUNK_DIR/cloudopsCA.$SPLUNK_CLOUDOPS_ROOTCA_FORMAT
$(etcd-get /splunk/config/cloudops/ca-cert | awk '{gsub(/\\n/,"\n")}1')
EOF
cat << EOF > /$SPLUNK_DIR/cloudopsForwarder.$SPLUNK_CLOUDOPS_CERTPATH_FORMAT
$(etcd-get /splunk/config/cloudops/forwarder-cert | awk '{gsub(/\\n/,"\n")}1')
EOF

#generate forwardering endpoints
cat << EOF >> /$SPLUNK_DIR/outputs.conf
[tcpout:splunkssl]
server = $SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST
sslCertPath = /opt/splunk/etc/system/local/cloudopsForwarder.$SPLUNK_CLOUDOPS_CERTPATH_FORMAT
sslRootCAPath = /opt/splunk/etc/system/local/cloudopsCA.$SPLUNK_CLOUDOPS_ROOTCA_FORMAT
sslPassword = $SPLUNK_CLOUDOPS_SSLPASSWORD

EOF
fi
