#!/bin/bash

SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
APP_HOME=`dirname "$SCRIPT_PATH"`
APP_NAME=`basename "$APP_HOME"`
source ${APP_HOME}/instance.profile
source /opt/$USER/script/shell/current/common_start_stop.sh
info "Starting [${APP_NAME}] : $APP_HOME"

if [ "$LANGUAGE" == "java" ]; then
  JAVA_OPTS_ALL="${JVM_OPTIONS} $JAVA_APP_OPTS $JAVA_GC_OPTS"
  if [ "$ARTIFACT_SUFFIX" == "jar"  ]; then
    STAR_CMD="${JDK_PATH:-java} -jar $JAVA_OPTS_ALL $JAR_FILE"
  else
    CONFIG_DIR="${APP_HOME}/current/config/"
    STAR_CMD="${JDK_PATH:-java} -jar $JAVA_OPTS_ALL ${APP_HOME}/current/boot/$ARTIFACT_ID.jar --spring.config.location=${CONFIG_DIR} "
  fi
elif [ -f "${APP_HOME}/bin/start.sh" ]; then
  source "${APP_HOME}/bin/start.sh"
elif [ -f "${APP_HOME}/run.sh" ]; then
  source "${APP_HOME}/run.sh"
fi
#----command---
start
