#!/bin/bash

DEPLOYMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $DEPLOYMENT_DIR/../config/parser-server.sh

function check_url() {
  http_status_code=$(curl -s -m 5 -IL --ssl-no-revoke $1 | grep HTTP | awk -v FS=" " '{print $2}')
  echo $http_status_code
}

#http://core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/script/common/maven-metadata.xml
function get_nexus_url() {
  local group_id=$1    #com.luopc.script
  local artifact_id=$2 #common
  local file=$3        #maven-metadata.xml

  local nexus_url=$(get_nexus_auth_url)
  local url_group_id=$(echo $group_id | sed "s/\./\//g")
  echo $nexus_url/$url_group_id/$artifact_id/$file
}

#http://core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/script/common/1.2.1-SNAPSHOT/maven-metadata.xml
function get_nexus_url_by_version() {
  local group_id=$1    #com.luopc.script
  local artifact_id=$2 #common
  local version=$3     #1.2.1-SNAPSHOT
  local file=$4        #maven-metadata.xml

  local nexus_url=$(get_nexus_auth_url)
  local url_group_id=$(echo $group_id | sed "s/\./\//g")
  echo $nexus_url/$url_group_id/$artifact_id/$version/$file
}

# 获取带认证的 Nexus URL
function get_nexus_auth_url() {
  local base_url=$(get_nexus_config "baseUrl")
  local username=$(get_nexus_config "username")
  local password=$(get_nexus_config "password")

  if [ -z "$base_url" ]; then
    error "Nexus base URL is empty"
    return 1
  fi
  if [ -z "$username" ]; then
    error "Nexus username is empty"
    return 1
  fi
  if [ -z "$password" ]; then
    error "Nexus password is empty"
    return 1
  fi

  echo "$base_url" | sed "s|https://|https://$username:$password@|"
  return 0
}

# 从Nexus下载文件到指定输出路径
function pull_from_nexus() {
  local download_path=$1
  local out_put=$2
  local http_status=$(check_url "$download_path")

  if [[ "$http_status" -ne "200" ]]; then
    echo "ERROR $http_status"
    return 1
  fi
  info "--------------------------------downloading-----------------------------------------"
  # 处理输出路径
  if [[ "$out_put" == *"/" ]]; then
    # 如果是目录路径
    mkdir -p "$out_put" || {
      error "Failed to create directory: $out_put"
      return 1
    }
    wget --timeout=3000 --tries=3 -nv --show-progress -P "$out_put" "$download_path"
  else
    wget --timeout=3000 --tries=3 -nv --show-progress -O "$out_put" "$download_path"
  fi
  info "-----------------------------------end-----------------------------------------------"
  sleep 1s
  return 0
}
