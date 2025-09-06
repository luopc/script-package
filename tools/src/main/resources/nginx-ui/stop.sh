#!/bin/bash
APP_HOME=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
THIS_PATH=$APP_HOME/`basename "${BASH_SOURCE[0]}"`
FULL_COMP_NAME=`dirname $THIS_PATH`
APP_NAME=`basename $FULL_COMP_NAME`

. $APP_HOME/instance.profile
. $APP_HOME/run.sh

stop