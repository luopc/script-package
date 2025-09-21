#!/bin/bash

SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
APP_HOME=`dirname "$SCRIPT_PATH"`
APP_NAME=`basename "$APP_HOME"`
source ${APP_HOME}/instance.profile
source /opt/$USER/script/shell/current/common_start_stop.sh
info "Starting [${APP_NAME}] : $APP_HOME"

if [ -f "${APP_HOME}/run.sh" ]; then
  source "${APP_HOME}/run.sh"
else
  if [ "$ARTIFACT_SUFFIX" == "jar"  ]; then
    JAVA_OPTS_ALL="${JVM_OPTIONS} $JAVA_APP_OPTS $JAVA_GC_OPTS"
    STAR_CMD="${JDK_PATH:-java} -jar $JAVA_OPTS_ALL $JAR_FILE"
  else
    STAR_CMD="sh ${APP_HOME}/current/bin/start.sh"
  fi
fi
#----command---
start
