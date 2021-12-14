#!/usr/bin/env bash

# remove the pid file on start to avoid mid start to hang
rm -rf /opt/servicenow/mid/agent/work/mid.pid

# Log
log() {
  echo "[$(date --rfc-3339=seconds)]: $*"
}

# Pin Container
pincontainer() {
	log "Pinning container"
	exec tail -f /dev/null
}

# Pin Container
pincontainer