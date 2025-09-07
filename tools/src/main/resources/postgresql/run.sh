#!/bin/bash
. /opt/$USER/script/shell/current/common_start_stop.sh

#$APP_HOME/current/bin/pg_ctl -D $APP_HOME/data/ -l logfile start（启动数据库）
#$APP_HOME/current/bin/pg_ctl -D $APP_HOME/data/ stop            （停止数据库）
#$APP_HOME/current/bin/pg_ctl restart -D $APP_HOME/data/ -m fast （重启数据库）
function go_to_start() {
  LOG_DATE=$(date +%Y%m%d)
  LOG_PATH=$APP_HOME/log
  nohup $APP_HOME/current/bin/pg_ctl -D $APP_HOME/data/ -l $APP_HOME/log/$APP_NAME-$LOG_DATE.log start >> $APP_HOME/log/$APP_NAME.console-$LOG_DATE.log 2>&1 &
}
STAR_CMD="$APP_HOME/current/bin/pg_ctl -D $APP_HOME/data/ -c port=5432 -l $APP_HOME/logs/$APP_NAME-$LOG_DATE.log start"
STOP_CMD="$APP_HOME/current/bin/pg_ctl -D $APP_HOME/data/ stop"
