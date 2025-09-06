#!/bin/bash

#/etc/rc.local
#/opt/root/script/current/./service-init.sh

function service_stop() {
  START_TIME=$(date +%Y-%m-%d_%H:%M:%S)
  APPS_PATH=/home/public/uat/apps
  echo "+-----------------------------------------------------------------------------------+"
  echo "   running user = [$USER], server = [$HOSTNAME] is started at [$START_TIME]         "
  echo "   path = [$APPS_PATH]                                                             "
  echo "+-----------------------------------------------------------------------------------+"

  for app_full_name in $(ls -A $APPS_PATH)
  do
    if [[ -f "$APPS_PATH/$app_full_name/instance.profile" ]]; then
      if [[ "$(grep -Fxq "export CURRENT_STATUS=1" "$APPS_PATH/$app_full_name/instance.profile" && echo "true")" = "true" ]]; then
        echo "                            ->|STATUS=1, INSTANCE[$app_full_name] SHOULD START|<-                                    "
        stop_app "$APPS_PATH" "$app_full_name"
        sleep 5s #wait for 5 seconds
      else
        echo "                            ->|STATUS=0, INSTANCE[$app_full_name] SHOULD NOT START|<-                                    "
      fi
    else
      echo "                            ->|Didn't set export CURRENT_STATUS for $app_full_name|<-                                    "
    fi
  done

  echo "+-----------------------------------------------------------------------------------+"
  echo "|                               ALL JOB COMPLETED                                   |"
  echo "+-----------------------------------------------------------------------------------+"
}

#ssh -q robin@data-server "sh /opt/public/apps/node_exporter/start.sh"
stop_app() {
  APPS_PATH=$1
  APP_NAME=$2
  if [[ -f "$APPS_PATH/$APP_NAME/stop.sh" ]]; then
    echo "                   "
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Start $APP_NAME ..."
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] DEBUG: Running command: sh $APPS_PATH/$APP_NAME/stop.sh "

    cd "$APPS_PATH/$APP_NAME" && sh stop.sh

    sleep 10
  fi
}

if [ $# == 0 ]; then
  service_stop
fi
