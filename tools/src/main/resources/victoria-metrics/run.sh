#!/bin/bash
. /opt/$USER/script/current/common.sh

#!<--加载prometheus conig--> -promscrape.config=$APP_HOME/conf/prometheus.yml
STAR_CMD="$APP_HOME/current/victoria-metrics -httpListenAddr=:9095 -retentionPeriod=30d -loggerTimezone=Asia/Shanghai -storageDataPath=data"
