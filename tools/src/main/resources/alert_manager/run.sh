#!/bin/bash
. /opt/$USER/script/current/common.sh

STAR_CMD="$APP_HOME/current/alertmanager --config.file=$APP_HOME/conf/alertmanager.yml --storage.path=$APP_HOME/data/ --web.listen-address=:9093"
