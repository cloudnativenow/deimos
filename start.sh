#!/usr/bin/env bash
# set -x

# remove the pid file on start to avoid mid start to hang
rm -rf /opt/servicenow/mid/agent/work/mid.pid

# # # # #
# Check if the mid server was registered correctly
#
# If the container is killed before the setup has completed and the MID
# was registered correctly, the sys_id is missing in the config.xml file
#
if [[ -f /opt/servicenow/mid/agent/config.xml ]]
then
    if [[ -z `grep -oP 'name="mid_sys_id" value="\K[^"]{32}' /opt/servicenow/mid/agent/config.xml` ]]
    then
        echo "Docker: config.xml invalid, reconfigure MID server"
        rm -rf /opt/servicenow/mid/agent/config.xml
    fi
fi

# # # # #
# First run, configure the properties in config.xml
# subsequent run, ensure MID status is down
# 
if [[ ! -f /opt/agent/config.xml ]]
then
    
    cp /opt/servicenow/mid/agent/config.xml.orig /opt/servicenow/mid/agent/config.xml
    
    if [[ ! -z "$INSTANCE_URL" ]]
    then
        echo "Docker: configuring url using ${INSTANCE_URL}"
        sed -i "s|https://YOUR_INSTANCE.service-now.com|${INSTANCE_URL}|g" /opt/servicenow/mid/agent/config.xml
    fi
 
    echo "Docker: configuring mid.instance.username using ${MID_USERNAME}"
    sed -i "s|YOUR_INSTANCE_USER_NAME_HERE|${MID_USERNAME}|g" /opt/servicenow/mid/agent/config.xml
    echo "Docker: configuring mid.instance.password using ******"
    sed -i "s|YOUR_INSTANCE_PASSWORD_HERE|${MID_PASSWORD}|g" /opt/servicenow/mid/agent/config.xml
    echo "Docker: configuring name using ${MID_NAME}"
    sed -i "s|YOUR_MIDSERVER_NAME_GOES_HERE|${MID_NAME}|g" /opt/servicenow/mid/agent/config.xml

else 
    # if the MID server was killed while status was UP in servicenow
    # the start process hangs with error message about already a MID
    # running with the same name :-| to fix, ensure the status is DOWN

    echo "DOCKER: update MID sever status";

    SYS_ID=`grep -oP 'name="mid_sys_id" value="\K[^"]{32}' /opt/servicenow/mid/agent/config.xml`
    URL=`grep -oP '<parameter name="url" value="\K[^"]+' /opt/servicenow/mid/agent/config.xml`

    if [[ -z "$SYS_ID" || -z "$URL" ]]
    then
        echo "DOCKER: update MID sever status: SYS_ID ($SYS_ID) or URL ($URL) not specified!";
    else
        echo "DOCKER: update MID sever status to DOWN";
        wget -O- --method=PUT --body-data='{"status":"Down"}' \
            --header='Content-Type:application/json' \
            --user "${MID_USERNAME}" --password "${MID_PASSWORD}" \
            ${WGET_CUSTOM_CACERT} \
            "${URL}/api/now/table/ecc_agent/${SYS_ID}?sysparm_fields=status"
        echo -e ""
    fi
fi

# Logmon
logmon(){
    echo "DOCKER MONITOR: $1"
}

# SIGTERM-handler
term_handler() {
    echo "DOCKER: Stop MID server"
    /opt/servicenow/mid/agent/bin/mid.sh stop & wait ${!}
    exit 143; # 128 + 15 -- SIGTERM
}

# Log
log() {
  echo "[$(date --rfc-3339=seconds)]: $*"
}

# Pin Container
pincontainer() {
	log "Pinning container"
	exec tail -f /dev/null
}

trap 'kill ${!}; term_handler' SIGTERM
touch /opt/servicenow/mid/agent/logs/agent0.log.0
echo "DOCKER: Start MID server"
/opt/servicenow/mid/agent/bin/mid.sh start &

# # # # # # # # #
# Logfile Monitor
# if by any chance the MID server hangs (e.g. upgrade) the log file will not be updated
# in that case force the container to stop
#

# log file to check
log_file=/opt/servicenow/mid/agent/logs/agent0.log.0

# max age of log file
ctime_max=300

# interval to check the log file
log_interval=30

# pid of this shell process
pid=$$
while true
do
    # check last log modification time
    ctime="$(ls ${log_file} --time=ctime -l --time-style=+%s | awk '{ print $6 }')"
    ctime_current="$(date +%s)"
    ctime_diff="$((ctime_current-ctime))"
    logmon "${log_file} last updated ${ctime_diff} sec ago"

    if [ "${ctime_diff}" -ge "${ctime_max}" ]; then
        logmon "${log_file} was not updated for ${ctime_max}sec, MID server potentially frozen."
        logmon "Stopping MID server process $pid now!"
        kill -TERM $pid
        break
    else
        #logmon "sleep"
        sleep $log_interval
    fi
done  &

# show the logs in the console
while true
do
    tail -F /opt/servicenow/mid/agent/logs/agent0.log.0 & wait ${!}
done

# Pin Container
# pincontainer