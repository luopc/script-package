#!/bin/bash
. /opt/$USER/script/current/common.sh

STAR_CMD="$APP_HOME/current/bin/redis-server $APP_HOME/conf/redis.conf"
STOP_CMD="$APP_HOME/current/bin/redis-cli -h 127.0.0.1 -p 7071 -a Luopc2021 shutdown"