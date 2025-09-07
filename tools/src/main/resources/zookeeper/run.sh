#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

STAR_CMD="$APP_HOME/current/bin/zkServer.sh start $APP_HOME/conf/zoo.cfg"
STOP_CMD="$APP_HOME/current/bin/zkServer.sh stop"
STATUS_CMD="$APP_HOME/current/bin/zkServer.sh status"
PID_CMD="ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|awk '{print \$2}'"
