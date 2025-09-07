#!/bin/bash

DEPLOYMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $DEPLOYMENT_DIR/utils/common_util.sh

#APP_NAME=${app_name}
#APP_HOME=${app_path}
LOG_DATE=$(date +%y%m%d-%H%M%S)
LOG_PATH=$APP_HOME/logs
LOG_NAME=${APP_NAME:-default}.console-$LOG_DATE.log
LOG_FILE=$LOG_PATH/$LOG_NAME

JAVA_OPTS="-Xms128m -Xmx512m -Dspring.profiles.active=${USER} -Denv=${USER}"
JAR_FILE=$APP_HOME/current/$ARTIFACT_ID$ARTIFACT_SUFFIX

PID_CMD="ps -ef|grep apps|grep $USER|grep $APP_NAME|grep -v grep|grep -v sh|grep -v kill|awk '{print \$2}'"
STAR_CMD="java -jar $JAVA_OPTS $JAR_FILE"

function show_help() {
  echo "+-----------------------------------------------------------------------+"
  echo "|     This is an application running script...                          |"
  echo "|     deploy apps     :     deploy -p $APP_NAME -v <version>            |"
  echo "|     deploy component:     deploy -i $APP_NAME -v <version>            |"
  echo "|     start-script    :     ./run.sh start                              |"
  echo "|     stop-script     :     ./run.sh stop                               |"
  echo "|     restart-script  :     ./run.sh restart                            |"
  echo "|     query-script    :     ./run.sh query                              |"
  echo "+-----------------------------------------------------------------------+"
}

function go_to_start() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: "
  green_line ">>> nohup $STAR_CMD >> $LOG_FILE &"
  #-server.port=8081
  nohup $STAR_CMD >>$LOG_FILE 2>&1 &
}

function start() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Going to start $APP_NAME in server [$HOSTNAME], CURRENT_STATUS = $CURRENT_STATUS. "

  PID=$(query_pid $APP_HOME)

  if [[ ${PID} ]]; then
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME is already running, pid = $PID...  "
  elif [[ $CURRENT_STATUS -eq '0' ]]; then
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Instance activation is $CURRENT_STATUS, skip starting"
  else
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: start $APP_NAME"
    if [[ ! -d $LOG_PATH ]]; then
      mkdir -p $LOG_PATH
    fi
    #--web.listen-address="0.0.0.0:19090"
    go_to_start

    WAIT_TIME=0
    while (($WAIT_TIME <= 10)); do
      sleep 1
      PID=$(query_pid $APP_HOME)
      if [[ ${PID} ]]; then
        WAIT_TIME=100
        compress_log "$LOG_PATH" "*console-*.log"
        info "$APP_NAME activation completed"
        info "Process pid: $PID"
        info "Console log: $LOG_FILE"
      else
        WAIT_TIME=$((WAIT_TIME + 1))
      fi
    done

    if [[ -z ${PID} ]]; then
      error "Fail to start, please check the log!"
      info "Log file: $LOG_FILE"
    fi
  fi
}

function stop() {
  PVERSION=$(query_version)
  debug "APP_HOME = $APP_HOME, running version = $PVERSION"

  if [[ $STOP_CMD ]]; then
    info "going to stop APP[$APP_NAME]"
    green_line ">>> $STOP_CMD "
    info "Log output: $LOG_FILE"
    nohup $STOP_CMD >>$LOG_FILE 2>&1 &
    sleep 10
  fi

  PID=$(query_pid $APP_HOME)
  if [[ ${PID} ]]; then
    info "Stop Process pid = $PID ...  "
    green_line ">>> kill -15 $PID "
    kill -15 $PID
    WAIT_TIME=0
    while (($WAIT_TIME <= 30)); do
      sleep 2
      PID=$(query_pid $APP_HOME)
      if [[ -z ${PID} ]]; then
        WAIT_TIME=100
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME shutdown completed"
      else
        WAIT_TIME=$((WAIT_TIME + 1))
      fi
    done
  fi

  PID=$(query_pid $APP_HOME)
  if [[ ${PID} ]]; then
    info "Kill Process pid = $PID ...  "
    green_line ">>> kill -9 $PID "
    kill -9 $PID
  else
    info "Stop Success!"
  fi
}

function restart() {
  info "Going to restart $APP_NAME in server [$HOSTNAME]"

  stop
  WAIT_TIME=0
  while (($WAIT_TIME <= 30)); do
    sleep 2
    PID=$(query_pid $APP_HOME)
    if [[ -z ${PID} ]]; then
      WAIT_TIME=100
      info "$APP_NAME shutdown completed, going to restart..."
      start
    else
      WAIT_TIME=$((WAIT_TIME + 1))
    fi
  done

}

function query() {
  PID=$(query_pid)
  PVERSION=$(query_version)


  if [[ ${PID} ]]; then
    #echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME is running.."
    info "pid = $PID  "
    info "version = $PVERSION  "
    echo "+-----------------------------------summary------------------------------------+"
    pid_info "$PID"
    if [[ $STATUS_CMD ]]; then
      PSTATUS=$(eval $STATUS_CMD)
      echo "$PSTATUS"
      echo "+------------------------------------------------------------------------------+"
    fi
  else
    info "ACTIVATION_STATUS is [$CURRENT_STATUS], $([[ $CURRENT_STATUS == 1 ]] && echo "expected to be started" || echo "skip starting") "
    info "$APP_NAME is not running.  "
  fi
}

function pid_info() {
  P=$1
  n=`ps -aux| awk '$2~/^'$P'$/{print $11}'|wc -l`
  if [ $n -eq 0 ];then
   echo "该PID不存在！！"
   exit
  fi
  echo "--------------------------------"
  echo "进程PID: $P"
  echo "进程命令：`ps -aux| awk '$2~/^'$P'$/{print $11}'`"
  echo "进程所属用户: `ps -aux| awk '$2~/^'$P'$/{print $1}'`"
  echo "CPU占用率：`ps -aux| awk '$2~/^'$P'$/{print $3}'`%"
  echo "内存占用率：`ps -aux| awk '$2~/^'$P'$/{print $4}'`%"
  echo "进程开始运行的时刻：`ps -aux| awk '$2~/^'$P'$/{print $9}'`"
  echo "进程运行的时间：`ps -aux| awk '$2~/^'$P'$/{print $10}'`"
  echo "进程状态：`ps -aux| awk '$2~/^'$P'$/{print $8}'`"
  echo "进程虚拟内存：`ps -aux| awk '$2~/^'$P'$/{print $5}'`"
  echo "进程共享内存：`ps -aux| awk '$2~/^'$P'$/{print $6}'`"
  echo "--------------------------------"
}

function query_pid() {
  #$( ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|grep -v kill|awk '{print $2}')
  tpid=$(eval $PID_CMD)
  echo $tpid
}

function query_version() {
  tversion=$(ls -al $APP_HOME/current | awk '{print $11}' | awk -v FS="/" '{print $2}')
  echo $tversion
}

function compress_log() {
  FOLDER_PATH=$1
  PATTERN=$2
  #remove file
  find -L $FOLDER_PATH -mindepth 1 -maxdepth 1 -name "*.gz" -type f -mtime +15 -exec rm -f {} \;

  #compresse file
  for FILE in $(find -L $FOLDER_PATH -mindepth 1 -maxdepth 1 -name "$PATTERN" | sort -n | sed '$d'); do
    gzip -f $FILE
    #echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $FILE is compressed."
  done
}

function show_head() {
  echo "+------------------------------------------------------------------------------------------------------+"
  echo "                         This is the application [$APP_NAME] running script...                         "
  echo "+                                        Starting to print Log                                         +"
}

if [ $# == 0 ]; then
  show_head
elif [[ $1 == "start" ]]; then
  start
elif [[ $1 == "stop" ]]; then
  stop
elif [[ $1 == "restart" ]]; then
  restart
elif [[ $1 == "query" ]]; then
  query
fi
