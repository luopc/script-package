#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

PID_CMD="ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|awk '{print \$2}'"
