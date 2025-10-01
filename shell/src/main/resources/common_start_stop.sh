#!/bin/bash

DEPLOYMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $DEPLOYMENT_DIR/utils/common_util.sh

#APP_NAME=${app_name}
#APP_HOME=${app_path}
LOG_DATE=$(date +%y%m%d-%H%M%S)
LOG_PATH=$APP_HOME/logs

GC_LOG_NAME=${CURRENT_APP:-app}.${CURRENT_INSTANCE:-primary}.${CURRENT_GROUP:-default}.${USER:-uat}.gc-$LOG_DATE.log
SAFE_POINT_LOG_NAME=${CURRENT_APP:-app}.${CURRENT_INSTANCE:-primary}.${CURRENT_GROUP:-default}.${USER:-uat}.safepoint-$LOG_DATE.log
GC_ALL_LOG_NAME=${CURRENT_APP:-app}.${CURRENT_INSTANCE:-primary}.${CURRENT_GROUP:-default}.${USER:-uat}.gc-$LOG_DATE.log
# 设置符合 JDK9+ 的分离日志参数
JAVA_GC_OPTS="-Xlog:gc*=info:file=${LOG_PATH}/${GC_LOG_NAME}:time,uptimemillis,level,tags:filecount=14,filesize=100M"
JAVA_GC_OPTS="$JAVA_GC_OPTS -Xlog:safepoint*=info:file=${LOG_PATH}/${SAFE_POINT_LOG_NAME}:time,uptimemillis,level,tags:filecount=5,filesize=50M"
JAVA_GC_OPTS="$JAVA_GC_OPTS -Xlog:all=warning:file=${LOG_PATH}/${GC_ALL_LOG_NAME}:time,uptimemillis,level,tags"

CONSOLE_LOG_NAME=${CURRENT_APP:-app}.${CURRENT_INSTANCE:-primary}.${CURRENT_GROUP:-default}.${USER:-uat}.console-$LOG_DATE.log
LOG_FILE=$LOG_PATH/$CONSOLE_LOG_NAME
PID_FILE="$APP_HOME/version/${APP_NAME:-default}.pid"
CMD_FILE="$APP_HOME/version/${APP_NAME:-default}.cmd"
DVERSION=$(ls -al $APP_HOME/current | awk '{print $11}' | awk -v FS="/" '{print $2}')

#==========================================================================================
# JVM Configuration
# -Xmx256m:设置JVM最大可用内存为256m,根据项目实际情况而定，建议最小和最大设置成一样。
# -Xms256m:设置JVM初始内存。此值可以设置与-Xmx相同,以避免每次垃圾回收完成后JVM重新分配内存
# -Xmn512m:设置年轻代大小为512m。整个JVM内存大小=年轻代大小 + 年老代大小 + 持久代大小。
#          持久代一般固定大小为64m,所以增大年轻代,将会减小年老代大小。此值对系统性能影响较大,Sun官方推荐配置为整个堆的3/8
# -XX:MetaspaceSize=64m:存储class的内存大小,该值越大触发Metaspace GC的时机就越晚
# -XX:MaxMetaspaceSize=320m:限制Metaspace增长的上限，防止因为某些情况导致Metaspace无限的使用本地内存，影响到其他程序
# -XX:-OmitStackTraceInFastThrow:解决重复异常不打印堆栈信息问题
#==========================================================================================
JAVA_OPT="-server -Xms256m -Xmx256m -Xmn512m -XX:MetaspaceSize=64m -XX:MaxMetaspaceSize=256m"
JAVA_APP_OPTS="-XX:-OmitStackTraceInFastThrow -Dspring.profiles.active=${USER:-uat} -Dapp=${CURRENT_APP} -Dversion=${DVERSION} -Dgroup=${CURRENT_GROUP} -Dinstance=${CURRENT_INSTANCE} -Denv=${USER:-uat} -Dhost=${HOSTNAME} -DlocalPath=${APP_HOME}"
JAVA_OPTS_ALL="$JAVA_OPT $JAVA_APP_OPTS $JAVA_GC_OPTS"
JAR_FILE=$APP_HOME/current/$ARTIFACT_ID.$ARTIFACT_SUFFIX

PID_CMD="ps -ef|grep 'apps\|tools'|grep $(getUser)|grep $APP_NAME|grep -v grep|grep -v sh|grep -v kill|awk '{print \$2}'"
STAR_CMD="java -jar $JAVA_OPTS_ALL $JAR_FILE"

function go_to_start() {
  info "Going to start $APP_NAME in server [$HOSTNAME]...  "
  green_line ">>> nohup $STAR_CMD >> $LOG_FILE &"
  #-server.port=8081
  nohup $STAR_CMD >>$LOG_FILE 2>&1 & echo $! > "$PID_FILE"
  echo $STAR_CMD > "$CMD_FILE"
}

function start() {
  info "Going to start $APP_NAME in server [$HOSTNAME], CURRENT_STATUS = $CURRENT_STATUS. "

  PID=$(query_pid $APP_HOME)

  if [[ ${PID} ]]; then
    cyan_line "$APP_NAME is already running, pid = $PID...  "
  elif [[ $CURRENT_STATUS -eq '0' ]]; then
    warn "Instance activation is $CURRENT_STATUS, skip starting"
  else
    info "start $APP_NAME"
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
        #compress_log "$LOG_PATH" "*console-*.log"
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
  debug "APP_HOME = $APP_HOME, running version = $PVERSION, PID = $PID"

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
        info " $APP_NAME shutdown completed"
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

  rm -f "$PID_FILE"
  rm -f "$CMD_FILE"
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
    info "$APP_NAME is running.."
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
    info "ACTIVATION_STATUS is [$CURRENT_STATUS], $([[ "$CURRENT_STATUS" == 1 ]] && echo "expected to be started" || echo "skip starting") "
    info "$APP_NAME is not running.  "
  fi
}

function query_pid() {
  #$( ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|grep -v kill|awk '{print $2}')
  if [ -f "$PID_FILE" ]; then
    tpid=$(cat "$PID_FILE")
    if ! ps -p "$tpid" >/dev/null 2>&1; then
      rm -f "$PID_FILE"
      tpid=$(eval $PID_CMD)
    fi
  else
    tpid=$(eval $PID_CMD)
  fi
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
    #echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$(getUser)] INFO: $FILE is compressed."
  done
}
