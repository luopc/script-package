#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh


STAR_CMD="$APP_HOME/current/sbin/rabbitmq-server -detached"
STOP_CMD="$APP_HOME/current/sbin/rabbitmqctl stop"
PID_CMD="ps -ef|grep boot|grep rabbit|grep -v grep|awk '{print \$2}'"

function query() {
  $APP_HOME/current/sbin/rabbitmqctl status
}
