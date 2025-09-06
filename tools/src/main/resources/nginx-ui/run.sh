#!/bin/bash
. /opt/$USER/script/current/common.sh

PID_CMD="ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|awk '{print \$2}'"