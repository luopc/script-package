#!/bin/bash

SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
APP_HOME=`dirname "$SCRIPT_PATH"`
APP_NAME=`basename "$APP_HOME"`
source ${APP_HOME}/instance.profile
source /opt/$USER/script/shell/current/common_start_stop.sh
info "Running [${APP_NAME}] : $APP_HOME"

if [ -f "${APP_HOME}/run.sh" ]; then
  source "${APP_HOME}/run.sh"
else
  if [ "$ARTIFACT_SUFFIX" == "jar"  ]; then
    JAVA_OPTS="-Xms128m -Xmx10248m -Dspring.profiles.active=${USER} -Dapp=${CURRENT_APP} -Dgroup=${CURRENT_GROUP} -Dinstance=${CURRENT_INSTANCE} -Denv=${USER} -Dhost=${HOSTNAME} -DlocalPath=${APP_HOME} "
    STAR_CMD="java -jar $JAVA_OPTS $JAR_FILE"
  else
    STAR_CMD="sh ${APP_HOME}/currrent/bin/start.sh"
  fi
fi

#----command---
restart
