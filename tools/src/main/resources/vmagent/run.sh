#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

# /path/to/vmagent -promscrape.config=/path/to/prometheus.yml -remoteWrite.url=https://victoria-metrics-host:8428/api/v1/write
STAR_CMD="$APP_HOME/current/vmagent -promscrape.config=$APP_HOME/conf/vmagent.yaml -remoteWrite.url=http://data-server.luopc.com:8428/api/v1/write"
