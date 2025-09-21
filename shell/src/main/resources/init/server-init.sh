#!/bin/bash
#cd /etc/rc.d/
#chmod +x rc.local
#vim /etc/rc.d/rc.local
#add /opt/robin/script/current/init/server-init.sh

ROOT_PATH=/opt/root/script/current/init/
LOG_PATH=/opt/root/logs/

function process_app() {
  if [[ $1 == "start" ]]; then
#    if [[ -f /opt/public/apps/nginx/start.sh ]]; then
#      echo "start nginx"
#      systemctl start keepalived
#    fi

    sleep 60s #sleep 60s

    LOG_FILE_NAME1=$LOG_PATH/server-init.robin-$(date +%Y%m%d).log
    LOG_FILE_NAME2=$LOG_PATH/server-init.uat-$(date +%Y%m%d).log

    timeout 1800 ssh -q robin@$HOSTNAME "sh /opt/robin/script/current/init/robin/apps-start.sh" >> "$LOG_FILE_NAME1" 2>&1 &
    sleep 180s #sleep 180s
    timeout 1800 ssh -q uat@$HOSTNAME "sh /opt/uat/script/current/init/uat/apps-start.sh" >> "$LOG_FILE_NAME2" 2>&1 &

    compress_log $LOG_PATH "server-init-*.log"

  elif [[ $1 == "stop" ]]; then
    echo "stop init service"

    LOG_FILE_NAME1=$LOG_PATH/server-shutdown.robin-$(date +%Y%m%d).log
    LOG_FILE_NAME2=$LOG_PATH/server-shutdown.uat-$(date +%Y%m%d).log

    timeout 1800 ssh -q uat@$HOSTNAME "sh /opt/uat/script/current/init/uat/apps-stop.sh" >> "$LOG_FILE_NAME2" 2>&1 &
    sleep 120s #sleep 120s
    timeout 1800 ssh -q robin@$HOSTNAME "sh /opt/robin/script/current/init/robin/apps-stop.sh" >> "$LOG_FILE_NAME1" 2>&1 &

  else
    print_log server-init.robin
    print_log server-init.uat
  fi

}


function compress_log() {
  FOLDER_PATH=$1
  PATTERN=$2
  for FILE in `find -L $FOLDER_PATH -mindepth 1 -maxdepth 1 -name "$PATTERN" | sort -n | sed '$d'`;
  do
    gzip -f $FILE
    echo "$FILE is compressed."
  done
}

function print_log() {
  PATTERN=$1
  LATEST_LOG_FILE=$(ls -lt $LOG_PATH | grep $PATTERN | grep -v gz | head -n 1|awk '{print $9}' )
  LOG_FILE=$LOG_PATH$LATEST_LOG_FILE
  if [[ -f $LOG_FILE ]];then
    tail -n 50 $LOG_FILE
  else
    echo "WARNING: Cannot find any log file under the path: $LOG_PATH"
  fi
}

if [ $# == 0 ]; then
    process_app start
else
  case $1 in
    start)
      process_app start
    ;;
    stop)
      process_app stop
    ;;
    status)
      process_app status
    ;;
    *)
      echo "require console | start | stop | status "
    ;;
  esac
fi
