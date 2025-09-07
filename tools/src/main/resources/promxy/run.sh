#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

STAR_CMD="$APP_HOME/current/promxy --config=$APP_HOME/conf/config.yaml --bind-addr=:9089 "
