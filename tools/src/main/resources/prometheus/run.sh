#!/bin/bash
. /opt/$USER/script/current/common.sh

#监控mysql:
# CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;
# GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
# --web.listen-address=:9090
STAR_CMD="$APP_HOME/current/prometheus --config.file=$APP_HOME/conf/prometheus.yml --storage.tsdb.path=$APP_HOME/data/ --log.level=debug --log.format=logfmt --web.enable-lifecycle"
