#!/bin/bash
#APP_NAME=${app_name}
#APP_HOME=${app_path}
#go_to_start=start command

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

function start() {
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Going to start $APP_NAME in server [$HOSTNAME], Instance status = $CURRENT_STATUS"

    PID=$( query_pid $APP_HOME )

    if [[ ${PID} ]]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME is already running, pid = $PID...  "
    elif [[ $CURRENT_STATUS == 0 ]]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Instance activation is $CURRENT_STATUS, skip starting"
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: start $APP_NAME"
        LOG_DATE=$(date +%Y%m%d)
        LOG_PATH=$APP_HOME/log
        if [[ ! -d $LOG_PATH ]]; then
          mkdir -p $LOG_PATH
        fi
        #--web.listen-address="0.0.0.0:19090"
        go_to_start

        WAIT_TIME=0
        while(( $WAIT_TIME<=10 ))
        do
            sleep 1
            PID=$( query_pid $APP_HOME )
            if [[ ${PID} ]]; then
                WAIT_TIME=100
                echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME activation completed"
                echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Process pid: $PID"
                echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Log path: $LOG_PATH/$APP_NAME.console-$LOG_DATE.log"
                compress_log "$APP_HOME/log" "$APP_NAME.console-*.log"
            else
                WAIT_TIME=$((WAIT_TIME + 1))
            fi
        done

        if [[ -z ${PID} ]]; then
          echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Fail to start, please check the log!"
          echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Log path: $LOG_PATH/$APP_NAME.console-$LOG_DATE.log"
        fi
    fi
}

function restart() {
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Going to restart $APP_NAME in server [$HOSTNAME]"

    stop
    sleep 2
    start
}

function stop() {
    PID=$( query_pid $APP_HOME )
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] DEBUG: APP_HOME = $APP_HOME"

    if [[ ${PID} ]]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Stop Process pid = $PID ...  "
        kill -15 $PID
    fi
    sleep 2

    PID=$( query_pid $APP_HOME )
    if [[ ${PID} ]]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Kill Process pid = $PID ...  "
        kill -9 $PID
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: Stop Success!"
    fi
}

function query() {
    PID=$( query_pid )
    PVERSION=$( query_version )

    if [[ ${PID} ]]; then
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME is running.."
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME pid = $PID  "
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME version = $PVERSION  "
    else
        echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $APP_NAME is not running.  "
    fi
}

function query_pid() {
    tpid=$( ps -ef|grep apps|grep $APP_NAME|grep -v grep|grep -v sh|grep -v kill|awk '{print $2}')
    echo $tpid
}

function query_version() {
    tversion=$( ls -al $APP_HOME/current|awk '{print $11}'|awk -v FS="/" '{print $2}' )
    echo $tversion
}

function compress_log() {
  FOLDER_PATH=$1
  PATTERN=$2
  for FILE in `find -L $FOLDER_PATH -mindepth 1 -maxdepth 1 -name "$PATTERN" | sort -n | sed '$d'`;
  do
    gzip -f $FILE
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] [$USER] INFO: $FILE is compressed."
  done
}

function show_head() {
    echo "+------------------------------------------------------------------------------------------------------+"
    echo "                         This is the application [$APP_NAME] running script...                         "
    echo "+----------------------------------------Starting to print Log-----------------------------------------+"
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
