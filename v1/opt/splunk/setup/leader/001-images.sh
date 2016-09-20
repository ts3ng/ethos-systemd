#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../../lib/helpers.sh

etcd-set /images/splunk					"index.docker.io/adobeplatform/docker-splunk:v1.0.0"
etcd-set /images/logging-config			"index.docker.io/adobeplatform/logging-config:latest"
etcd-set /images/splunk-heavyforwarder	"index.docker.io/adobeplatform/docker-splunk:heavyforwarder-latest"
etcd-set /images/splunk					"index.docker.io/adobeplatform/docker-splunk:latest"

######################
#       SPLUNK
######################
etcd-set /splunk/config/label-index "logging-index"
etcd-set /splunk/config/label-type "logging-type"
etcd-set /splunk/config/label-sourcetype "logging-sourcetype"
etcd-set /splunk/config/label-volume "logging-volume"
etcd-set /splunk/config/heavyforwarder-endpoint "https://localhost:8089"
etcd-set /splunk/config/heavyforwarder-auth "admin:changeme"
etcd-set /splunk/config/logging-config/poller-frequency 10
