#!/bin/bash

SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
APP_HOME=`dirname "$SCRIPT_PATH"`
APP_NAME=`basename "$APP_HOME"`
source ${APP_HOME}/instance.profile
source /opt/$USER/script/shell/current/common_start_stop.sh
info "Running [${APP_NAME}] : $APP_HOME"

if [ -f "${APP_HOME}/run.sh" ]; then
  source "${APP_HOME}/run.sh"
fi
stop
info "Stopping $APP_NAME version: $(query_version)"
