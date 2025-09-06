#!/bin/bash
. /opt/$USER/script/current/common.sh

#log4j file app.default.primary.uat.log
JAVA_OPTS="-Xms128m -Xmx10248m -Dspring.profiles.active=${USER} -Dapp=${CURRENT_APP} -Dgroup=${CURRENT_GROUP} -Dinstance=${CURRENT_INSTANCE} -Denv=${USER} -Dhost=${HOSTNAME} -DlocalPath=${APP_HOME} "
STAR_CMD="java -jar $JAVA_OPTS $JAR_FILE"