#!/usr/bin/bash -x
source /etc/environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

if [ "${NODE_ROLE}" != "logging" ]; then
    exit 0
fi

SPLUNK_DIR="/opt/splunk-fluentd/etc/system/local"
SPLUNK_ENABLE_CLOUDOPS_FORWARDER=$(etcd-get /splunk/config/cloudops/enable-forwarder)
SPLUNK_ENABLE_HEC_FORWARDER=$(etcd-get /splunk/config/hec/enable-forwarder)
SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST=$(etcd-get /splunk/config/cloudops/forward-server-list)
SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT=$(etcd-get /splunk/config/cloudops/hvc-endpoint)
SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT=$(etcd-get /splunk/config/cloudops/lvc-endpoint)
SPLUNK_CLOUDOPS_SSLPASSWORD=$(etcd-get /splunk/config/cloudops/sslpassword)
SPLUNK_CLOUDOPS_INDEX=$(etcd-get /splunk/config/cloudops/index)
SPLUNK_FORWARDER_HOST=`curl -s http://169.254.169.254/latest/meta-data/hostname`
SPLUNK_CLOUDOPS_CERTPATH_FORMAT=$(etcd-get /splunk/config/cloudops/certpath-format)
SPLUNK_CLOUDOPS_ROOTCA_FORMAT=$(etcd-get /splunk/config/cloudops/rootca-format)
SPLUNK_HEC_TOKEN=$(etcd-get /logging/config/fluentd-httpext-splunk-hec-token)
SPLUNK_HEC_HVC_TOKEN=$(etcd-get /logging/config/fluentd-httpext-splunk-hec-hvc-token)
SPLUNK_HEC_LVC_TOKEN=$(etcd-get /logging/config/fluentd-httpext-splunk-hec-lvc-token)
SPLUNK_HEC_ENDPOINT=$(etcd-get /logging/config/fluentd-httpext-splunk-url)
SPLUNK_HEC_DEFAULT_INDEX=$(etcd-get /splunk/config/hec/default-index)
SPLUNK_ENABLE_FLUENTD_PROXY=$(etcd-get /splunk/config/heavyforwarder/fluentd-proxy)
SPLUNK_ENABLE_JOURNALD_PROXY=$(etcd-get /splunk/config/heavyforwarder/journald-proxy)
SPLUNK_HEAVYFORWARDER_DEFAULT_PORT=$(etcd-get /splunk/config/heavyforwarder/default-port)
SPLUNK_HEAVYFORWARDER_PROXY_PORT=$(etcd-get /splunk/config/heavyforwarder/proxy-port)
SPLUNK_HEAVYFORWARDER_FLUENTD_TOKEN=$(etcd-get /splunk/config/heavyforwarder/fluentd-token)
SPLUNK_HEAVYFORWARDER_SYSTEM_TOKEN=$(etcd-get /splunk/config/heavyforwarder/system-token)
SPLUNK_ENABLE_SYSLOG_SCRUB=$(etcd-get /splunk/config/heavyforwarder/scrub-syslog)
SPLUNK_ENABLE_JOURNALD_SCRUB=$(etcd-get /splunk/config/scrub-syslog)
SPLUNK_SYSLOG_REGEX=$(etcd-get /splunk/config/syslog-scrub-regex)

#create splunk configuration directory
mkdir -p $SPLUNK_DIR


DEFAULTGROUP="splunkhvc"
DEFAULTINDEX=$SPLUNK_CLOUDOPS_INDEX

#formating tokens 
if [ $SPLUNK_HEC_TOKEN == "" ]; then
        SPLUNK_HEC_TOKEN=$(etcd-get /splunk/config/hec/token)
fi
if [ $SPLUNK_HEC_TOKEN == "" ] && [ $SPLUNK_HEC_HVC_TOKEN != "" ]; then
        SPLUNK_HEC_TOKEN=$SPLUNK_HEC_HVC_TOKEN
fi
if [ $SPLUNK_HEC_HVC_TOKEN == "" ] && [$SPLUNK_HEC_TOKEN != "" ]; then
        SPLUNK_HEC_HVC_TOKEN=$SPLUNK_HEC_TOKEN
fi
if [ $SPLUNK_HEC_LVC_TOKEN == "" ] && [$SPLUNK_HEC_TOKEN != "" ]; then
        SPLUNK_HEC_LVC_TOKEN=$SPLUNK_HEC_TOKEN
fi
if [[ $SPLUNK_HEC_TOKEN =~ ^Splunk ]]; then
        SPLUNK_HEC_TOKEN=`echo $SPLUNK_HEC_TOKEN | sed 's/[splunk| ]//gI'`
fi
if [[ $SPLUNK_HEC_HVC_TOKEN =~ ^Splunk ]]; then
        SPLUNK_HEC_HVC_TOKEN=`echo $SPLUNK_HEC_HVC_TOKEN | sed 's/[splunk| ]//gI'`
fi
if [[ $SPLUNK_HEC_LVC_TOKEN =~ ^Splunk ]]; then
        SPLUNK_HEC_LVC_TOKEN=`echo $SPLUNK_HEC_LVC_TOKEN | sed 's/[splunk| ]//gI'`
fi
#formating endpoints
if [ "$SPLUNK_HEC_ENDPOINT" == "" ] && [ "$SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT" != "" ]; then
        SPLUNK_HEC_ENDPOINT=$SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT
fi
if [ "$SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT" == "" ] && [ "$SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST" != "" ]; then
        SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT=$SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST
fi
if [ "$SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT" == "" ] && [ "$SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST" != "" ]; then
        SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT=$SPLUNK_FORWARD_CLOUDOPS_SERVER_LIST
fi
if [[ $SPLUNK_HEC_ENDPOINT =~ ^(https|http)://.*/services/collector ]]; then
        SPLUNK_HEC_ENDPOINT=`echo $SPLUNK_HEC_ENDPOINT | awk -F "/" '{print $3}'`
fi
if [[ $SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT =~ ^(https|http)://.*/services/collector ]]; then
        SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT=`echo $SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT| awk -F "/" '{print $3}'`
fi
if [[ $SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT =~ ^(https|http)://.*/services/collector ]]; then
        SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT=`echo $SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT| awk -F "/" '{print $3}'`
fi

###########
# Function: writeconfig
# heredocs for writing out splunk configuration files
###########
function writeConfig ()
{
case "$1" in
        inputs)
#default listener
cat << EOF > /$SPLUNK_DIR/$1.conf
[tcp://$SPLUNK_HEAVYFORWARDER_DEFAULT_PORT]
index = $DEFAULTINDEX
_TCP_ROUTING = $DEFAULTGROUP
EOF

# enable HEC Listener 
if [ "$SPLUNK_ENABLE_FLUENTD_PROXY" == "1" ] || [ "$SPLUNK_ENABLE_JOURNALD_PROXY" == "1" ] || [ "$SPLUNK_ENABLE_HEC_FORWARDER" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[http]
disabled = 0
enableSSL = 0
port = $SPLUNK_HEAVYFORWARDER_PROXY_PORT
outputGroup = $DEFAULTGROUP
EOF
fi
# enable customer logs from fluentd
if [ "$SPLUNK_ENABLE_FLUENTD_PROXY" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[http://ethos-hvc]
token = $SPLUNK_HEC_HVC_TOKEN
outputGroup = splunkhvc
disabled = 0
EOF
fi

if [ "$SPLUNK_HEC_LVC_TOKEN" != "$SPLUNK_HEC_HVC_TOKEN" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[http://ethos-lvc]
token = $SPLUNK_HEC_LVC_TOKEN
outputGroup = splunklvc
disabled = 0
EOF
fi
#system log listener events from journald-splunk pipe
if [ "$SPLUNK_ENABLE_JOURNALD_PROXY" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[http://system]
token = $SPLUNK_HEAVYFORWARDER_SYSTEM_TOKEN
index = $SPLUNK_CLOUDOPS_INDEX
outputGroup = splunkhec
disabled = 0
EOF
fi
        ;;
        outputs)
#setup defaults
cat << EOF > /$SPLUNK_DIR/$1.conf
[default]
defaultGroup = $DEFAULTGROUP
EOF
#generate cert auth log forwarding
if [ "$SPLUNK_ENABLE_CLOUDOPS_FORWARDER" == "1" ] || [ "$SPLUNK_ENABLE_FLUENTD_PROXY" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[tcpout:splunkhvc]
server = $SPLUNK_FORWARD_CLOUDOPS_HVC_ENDPOINT
sslCertPath = /opt/splunk/etc/system/local/cloudopsForwarder.$SPLUNK_CLOUDOPS_CERTPATH_FORMAT
sslRootCAPath = /opt/splunk/etc/system/local/cloudopsCA.$SPLUNK_CLOUDOPS_ROOTCA_FORMAT
sslPassword = $SPLUNK_CLOUDOPS_SSLPASSWORD

[tcpout:splunklvc]
server = $SPLUNK_FORWARD_CLOUDOPS_LVC_ENDPOINT
sslCertPath = /opt/splunk/etc/system/local/cloudopsForwarder.$SPLUNK_CLOUDOPS_CERTPATH_FORMAT
sslRootCAPath = /opt/splunk/etc/system/local/cloudopsCA.$SPLUNK_CLOUDOPS_ROOTCA_FORMAT
sslPassword = $SPLUNK_CLOUDOPS_SSLPASSWORD
EOF
fi
#generate hec log forwarding
if [ "$SPLUNK_ENABLE_HEC_FORWARDER" == "1" ] || [ "$SPLUNK_ENABLE_JOURNALD_PROXY" == "1" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[tcpout:splunkhec]
token = $SPLUNK_HEC_TOKEN
server = $SPLUNK_HEC_ENDPOINT:443
EOF
fi
        ;;
        transforms)
#setup defaults
cat << EOF > /$SPLUNK_DIR/$1.conf
[default_index]
REGEX = .
DEST_KEY = _MetaData:Index
FORMAT = $SPLUNK_HEC_DEFAULT_INDEX

[default_sourcetype]
REGEX = .
DEST_KEY = MetaData:Sourcetype
FORMAT = sourcetype::json

EOF
        ;;
        props)
cat << EOF > /$SPLUNK_DIR/$1.conf
[source::tcp:9997]
TRANSFORMS-index = default_index
TRANSFORMS-sourcetype = default_sourcetype
EOF

#setup logging scrubbing
if [ "$SPLUNK_ENABLE_JOURNALD_PROXY" == "1" ] && [ "$SPLUNK_ENABLE_SYSLOG_SCRUB" == "1" ] && [ "$SPLUNK_ENABLE_JOURNALD_SCRUB" == "0" ]; then
cat << EOF >> /$SPLUNK_DIR/$1.conf

[source::http:system]
SEDCMD-removeenvvars = $SPLUNK_SYSLOG_REGEX
EOF
fi
        ;;
        cloudopsCA)
cat << EOF > /$SPLUNK_DIR/$1.$SPLUNK_CLOUDOPS_ROOTCA_FORMAT
$(etcd-get /splunk/config/cloudops/ca-cert | awk '{gsub(/\\n/,"\n")}1')
EOF
        ;;
        cloudopsForwarder)
cat << EOF > /$SPLUNK_DIR/$1.$SPLUNK_CLOUDOPS_CERTPATH_FORMAT
$(etcd-get /splunk/config/cloudops/forwarder-cert | awk '{gsub(/\\n/,"\n")}1')
EOF
        ;;
        *)
        exit 1
        ;;
esac
}

function showOptions() {
        logger "SPLUNK_ENABLE_CLOUDOPS_FORWARDER: $SPLUNK_ENABLE_CLOUDOPS_FORWARDER"
        logger "SPLUNK_ENABLE_JOURNALD_PROXY: $SPLUNK_ENABLE_JOURNALD_PROXY"
        logger "SPLUNK_ENABLE_FLUENTD_PROXY: $SPLUNK_ENABLE_FLUENTD_PROXY"
        logger "SPLUNK_ENABLE_SYSLOG_SCRUB: $SPLUNK_ENABLE_SYSLOG_SCRUB"
        logger "SPLUNK_ENABLE_JOURNALD_SCRUB: $SPLUNK_ENABLE_JOURNALD_SCRUB"
}

writeConfig "inputs"
writeConfig "outputs"
writeConfig "cloudopsCA"
writeConfig "cloudopsForwarder"
writeConfig "props"
writeConfig "transforms"
showOptions
