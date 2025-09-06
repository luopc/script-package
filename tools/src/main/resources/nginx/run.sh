#!/bin/bash
. /opt/$USER/script/current/common.sh

STAR_CMD="$APP_HOME/current/sbin/nginxs -c $APP_HOME/conf/nginx.conf"
STOP_CMD="$APP_HOME/current/sbin/nginx -s stop"
