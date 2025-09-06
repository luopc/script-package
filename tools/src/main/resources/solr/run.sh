#!/bin/bash
. /opt/$USER/script/current/common.sh

STAR_CMD="$APP_HOME/current/bin/solr start -s /opt/public/apps/solr/current"
STOP_CMD="$APP_HOME/current/bin/solr stop"
PID_CMD="ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v kill|awk '{print \$2}'"
