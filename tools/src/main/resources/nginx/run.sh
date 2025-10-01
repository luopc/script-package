#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

STAR_CMD="$APP_HOME/current/sbin/nginx -c $APP_HOME/conf/nginx.conf"
STOP_CMD="$APP_HOME/current/sbin/nginx -s stop"
