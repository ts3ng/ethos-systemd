#!/bin/bash
CHRONOS_URL="http://localhost"
CHRONOS_PORT="4400"
CHRONOS_USERNAME="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /chronos/config/username)"
CHRONOS_PASSWORD="$(/home/core/ethos-systemd/v1/lib/etcdauth.sh get /chronos/config/password)"
SUMO_FILTER="APP_NAME='chronos-cleanup'"
if [[ "$CHRONOS_USERNAME" != "" && "$CHRONOS_PASSWORD" != "" ]]; then
  CHRONOS_AUTH="-u ${CHRONOS_USERNAME}:${CHRONOS_PASSWORD}"
else
  CHRONOS_AUTH=""
fi
ALL_JOBS="$(curl -s ${CHRONOS_AUTH} -L -X GET ${CHRONOS_URL}:${CHRONOS_PORT}/scheduler/jobs | jq -r '.[] | [ .schedule, .name ]| join(",")' )"
ALL_JOBS_STATE="$(curl -s ${CHRONOS_AUTH} -L -X GET ${CHRONOS_URL}:${CHRONOS_PORT}/scheduler/graph/csv)"
RUNNING_JOBS="$( echo "$ALL_JOBS_STATE" | grep ",running$")"
RUNNING_JOB_NAMES="$( echo "$RUNNING_JOBS" | awk -F ',' '{print $2}')"
OLD_JOBS="$(echo "$ALL_JOBS" | grep '^R0/')"
OLD_JOB_NAMES="$( echo "$OLD_JOBS" | awk -F ',' '{print $2}' )"
if [[ "$OLD_JOB_NAMES" != "" ]] ; then
  echo -e "$SUMO_FILTER Old jobs found:\n$OLD_JOB_NAMES\n"
  for job_name in $OLD_JOB_NAMES ; do
    job_running="$(echo "$RUNNING_JOB_NAMES" | grep "$job_name")"
    if [[ "$job_running" == "" ]] ; then
      echo -e "$SUMO_FILTER Deleting $job_name \n"
      DELETE_RETURN_CODE="$(curl -s --write-out '  curl return code: %{http_code}\n' -L -X DELETE ${CHRONOS_URL}:${CHRONOS_PORT}/scheduler/job/${job_name} )"
      echo -e "$SUMO_FILTER delete curl code for job $job_name: $DELETE_RETURN_CODE"
    else #It's still running, keep it alive for now
      echo -e "$SUMO_FILTER Skipping chronos job deletion for $job_name as the job is still running..."
    fi
  done
else
  echo "$SUMO_FILTER No old jobs found to be deleted."
fi
