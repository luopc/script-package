#!/bin/bash
#current_path=/opt/uat/apps/prometheus, this_path=/opt/uat/apps/prometheus/test.sh, full_comp_name=/opt/uat/apps/prometheus, app_name=prometheus
APP_HOME=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
THIS_PATH=$APP_HOME/`basename "${BASH_SOURCE[0]}"`
FULL_COMP_NAME=`dirname $THIS_PATH`
APP_NAME=`basename $FULL_COMP_NAME`

. $APP_HOME/instance.profile
. $APP_HOME/run.sh

#----command---
query
