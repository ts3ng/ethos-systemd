#!/bin/bash
if [[ -f /etc/profile.d/etcdctl.sh ]];  then
        source /etc/profile.d/etcdctl.sh
fi

source /etc/environment
###
# Note: script executes at midnight UTC based on splunk-journald-cleanup.timer
###
REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
RESTART_HOUR=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/univeralsforwarder/restarthour`
ENABLE_RESTART=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/universalforwarder/restart`
if [ "$1" == "heavyforwarder" ]; then
        RESTART_HOUR=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/heavyforwarder/restarthour`
        ENABLE_RESTART=`/home/core/ethos-systemd/v1/lib/etcdauth.sh get /splunk/config/heavyforwarder/restart`
fi

if [ "$ENABLE_RESTART" == "0" ]; then
        exit 0
fi

###
#
###
hour_to_sec ()
{
        echo "$(($1*3600))"
}

###
# adj_time : return legit military hour
##
adj_time ()
{
        if [ "$1" -gt 23 ]; then
                echo "$(($1-24))"
        elif [ "$1" -lt 0 ];then
                echo "$((24+$1))"
        else
                echo "$1"
        fi
}
TZCHECK=`/usr/bin/timedatectl | grep "Local time:"`
if [[ $TZCHECK  =~ UTC ]]; then
        DELAY=0
        UTC_RESTART_TIME=$RESTART_HOUR
        #set utc time based on region
        if [[ $REGION =~ ^us ]]; then
                #taking us-east as default time for us regions UTC-4
                UTC_RESTART_TIME=`echo "$(($RESTART_HOUR+4))"`
        elif [[ $REGION =~ ^ap ]]; then
                #taking tokyo as default time UTC+9
                UTC_RESTART_TIME=`echo "$(($RESTART_HOUR-9))"`
        elif [[ $REGION =~ ^eu ]]; then
                #taking ireland as default time UTC+1
                UTC_RESTART_TIME=`echo "$(($RESTART_HOUR-1))"`
        fi
        #adj time to 24 hour cycle
        UTC_RESTART_TIME=$(adj_time $UTC_RESTART_TIME)
        DELAY=$(hour_to_sec $UTC_RESTART_TIME)


        TZCHECK=`timedatectl | grep "Local time:"`
        echo "splunk cleanup timer: Restart time $REGION: $UTC_RESTART_TIME waiting: $DELAY"
        sleep $DELAY
else
        logger "restarting host at local time midnight"
fi

if [ "$1" == "heavyforwarder" ]; then
        /usr/bin/systemctl try-restart splunk-fluentd@$(echo "$COREOS_PRIVATE_IPV4").service
else
        /usr/bin/systemctl try-restart splunk-journald.service
fi
