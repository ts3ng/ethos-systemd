#!/usr/bin/bash
if [[ -f /etc/profile.d/etcdctl.sh ]];  then
        source /etc/profile.d/etcdctl.sh
fi

source /etc/splunk.env
# see what kind of forwarder is needed
ENABLE_SECOPS=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/secops/enable-forwarder`
ENABLE_CLOUDOPS=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/cloudops/enable-forwarder`
LOGGING_PORT=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/heavyforwarder/proxy-port`
LOGGING_ELB=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /environment/LOGGING_ELB`
LOGGING_INDEX=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/cloudops/index`
JOURNALD_PROXY=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/heavyforwarder/journald-proxy`
SYSTEM_TOKEN=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/heavyforwarder/system-token`
LOG_SCRUB_REGEX=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/syslog-scrub-regex`
ENABLE_SYSLOG_SCRUB=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/scrub-syslog`
ENABLE_SECOPS=`etcdctl get /splunk/config/secops/enable-forwarder`
ENABLE_CLOUDOPS=`etcdctl get /splunk/config/cloudops/enable-forwarder`
LOGGING_PORT=`etcdctl get /splunk/config/heavyforwarder/proxy-port`
LOGGING_ELB=`etcdctl get /environment/LOGGING_ELB`
LOGGING_INDEX=`etcdctl get /splunk/config/cloudops/index`
JOURNALD_PROXY=`etcdctl get /splunk/config/heavyforwarder/journald-proxy`
SYSTEM_TOKEN=`etcdctl get /splunk/config/heavyforwarder/system-token`
LOG_SCRUB_REGEX=`etcdctl get /splunk/config/syslog-scrub-regex`
ENABLE_SYSLOG_SCRUB=`etcdctl get /splunk/config/scrub-syslog`
CLOUDOPS_HEC_ENDPOINT=`etcdctl get /logging/config/fluentd-httpext-splunk-url`
SPLUNK_HEC_HVC_TOKEN=`etcdctl get /logging/config/fluentd-httpext-splunk-hec-hvc-token`

if [ "$JOURNALD_PROXY" == "1" ]; then
        logger "Journald proxy enabled"
        # wait for etcdctl value then proceed set on standup on logging tier
        if [ "$LOGGING_ELB" == "" ]; then
                LOGGING_ELB=`/home/core/ethos-systemd/v1/lib/etcdauth.sh watch /environment/LOGGING_ELB`
        fi
        #System Logs to Http Event Collector and SplunkES over CertAuth
        if [ "$ENABLE_SYSLOG_SCRUB" == "0" ]; then
                logger "syslog scrub disabled"
                if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                        if [ "$ENABLE_SECOPS" == "1" ]; then
                                journalctl -f | while read line; do curl -s -k $CLOUDOPS_HEC_ENDPOINT -H "Authorization: $SPLUNK_HEC_HVC_TOKEN" -d "{ \"event\": { \"log\": \"$(echo $line | sed "s/\"/\\\\\"/g")\", \"stack_name\": \"$STACK_NAME\", \"accountid\": \"$ACCOUNTID\", \"node_role\": \"$NODE_ROLE\", \"instanceid\": \"$INSTANCEID\", \"hostname\": \"$HOSTNAME\" }, \"index\": \"$LOGGING_INDEX\", \"sourcetype\": \"syslog\" }" > /dev/null; done &
                        else
                                journalctl -f | while read line; do curl -s -k $CLOUDOPS_HEC_ENDPOINT -H "Authorization: $SPLUNK_HEC_HVC_TOKEN" -d "{ \"event\": { \"log\": \"$(echo $line | sed "s/\"/\\\\\"/g")\", \"stack_name\": \"$STACK_NAME\", \"accountid\": \"$ACCOUNTID\", \"node_role\": \"$NODE_ROLE\", \"instanceid\": \"$INSTANCEID\", \"hostname\": \"$HOSTNAME\" }, \"index\": \"$LOGGING_INDEX\", \"sourcetype\": \"syslog\" }" > /dev/null; done
                        fi
                fi
                if [ "$ENABLE_SECOPS" == "1" ]; then
                        journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$line" | ncat --udp localhost 1514;done
                fi
        else
                logger "syslog scrub enabled"
                if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                        if [ "$ENABLE_SECOPS" == "1" ]; then
                                journalctl -f | while read line; do curl -s -k $CLOUDOPS_HEC_ENDPOINT -H "Authorization: $SPLUNK_HEC_HVC_TOKEN" -d "{ \"event\": { \"log\": \"$(echo $line | sed "$LOG_SCRUB_REGEX" | sed "s/\"/\\\\\"/g")\", \"stack_name\": \"$STACK_NAME\", \"accountid\": \"$ACCOUNTID\", \"node_role\": \"$NODE_ROLE\", \"instanceid\": \"$INSTANCEID\", \"hostname\": \"$HOSTNAME\" }, \"index\": \"$LOGGING_INDEX\", \"sourcetype\": \"syslog\" }" > /dev/null; done &
                        else
                                journalctl -f | while read line; do curl -s -k $CLOUDOPS_HEC_ENDPOINT -H "Authorization: $SPLUNK_HEC_HVC_TOKEN" -d "{ \"event\": { \"log\": \"$(echo $line | sed "$LOG_SCRUB_REGEX" | sed "s/\"/\\\\\"/g")\", \"stack_name\": \"$STACK_NAME\", \"accountid\": \"$ACCOUNTID\", \"node_role\": \"$NODE_ROLE\", \"instanceid\": \"$INSTANCEID\", \"hostname\": \"$HOSTNAME\" }, \"index\": \"$LOGGING_INDEX\", \"sourcetype\": \"syslog\" }" > /dev/null; done
                        fi
                fi
                if [ "$ENABLE_SECOPS" == "1" ]; then
                        journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$(echo $line | sed "$LOG_SCRUB_REGEX")" | ncat --udp localhost 1514;done
                fi
        fi
else
        #System Logs to local universal forwarder for splunkES and splunkAAS
        if [ "$ENABLE_SYSLOG_SCRUB" == "0" ]; then
                logger "syslog scrub disabled"
                if [ "$ENABLE_SECOPS" == "1" ]; then
                        if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                                journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$line" | ncat --udp localhost 1514;done &
                        else
                                journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$line" | ncat --udp localhost 1514;done
                        fi
                fi
                if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                        journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$line" | ncat --udp localhost 1515;done
                fi
        else
                logger "syslog scrub enabled \"$LOG_SCRUB_REGEX\""
                if [ "$ENABLE_SECOPS" == "1" ]; then
                        if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                                journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$(echo $line | sed "$LOG_SCRUB_REGEX")" | ncat --udp localhost 1514;done &
                        else
                                journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$(echo $line | sed "$LOG_SCRUB_REGEX")" | ncat --udp localhost 1514;done
                        fi
                fi
                if [ "$ENABLE_CLOUDOPS" == "1" ]; then
                        journalctl -f | while read line; do echo "STACK_NAME=$STACK_NAME ACCOUNTID=$ACCOUNTID NODE_ROLE=$NODE_ROLE INSTANCEID=$INSTANCEID HOSTNAME=$HOSTNAME LOG=$(echo $line | sed "$LOG_SCRUB_REGEX")" | ncat --udp localhost 1515;done
                fi
        fi
fi
