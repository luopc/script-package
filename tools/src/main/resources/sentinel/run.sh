#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

STAR_CMD="java -Dserver.port=7076 -Dcsp.sentinel.dashboard.server=localhost:7076 -Dproject.name=sentinel-dashboard -jar $APP_HOME/current/sentinel-dashboard.jar"
PID_CMD="ps -ef|grep apps|grep sentinel|grep -v grep|grep -v kill|awk '{print \$2}'"
