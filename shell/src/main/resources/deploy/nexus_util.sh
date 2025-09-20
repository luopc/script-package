#!/bin/bash

DEPLOYMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $DEPLOYMENT_DIR/../config/parser-server.sh

# Function: Check URL availability with retry logic and improved error handling
# 功能：检查URL可用性，支持重试机制和增强的错误处理
# 参数：
#   $1 - 要检查的URL（必需）
#   $2 - 最大重试次数（可选，默认3次）
#   $3 - 重试间隔（秒）（可选，默认2秒）
function check_url() {
  local url="$1"
  local max_retries=${2:-3}      # 默认重试3次
  local retry_delay=${3:-2}      # 默认间隔2秒
  local retries=0
  local http_status_code
  local curl_output

  # 参数有效性检查
  if [ -z "$url" ]; then
    echo "Error: URL parameter is empty" >&2
    return 1
  fi

  while [ $retries -lt $max_retries ]; do
    # 使用curl获取HTTP头信息（超时5秒，忽略SSL证书验证）
    # 添加--connect-timeout防止连接阶段无限等待
    curl_output=$(curl -s -m 5 --connect-timeout 5 -IL --ssl-no-revoke "$url" 2>/dev/null)

    # 提取状态码（更健壮的解析方式）
    http_status_code=$(echo "$curl_output" | grep -E '^HTTP/[0-9]+\.[0-9]+' | awk '{print $2}' | head -n1)

    # 成功状态码检测（2xx/3xx）
    if [[ "$http_status_code" =~ ^[23][0-9]{2}$ ]]; then
      echo "$http_status_code"
      return 0
    fi

    # 打印调试信息（非第一次重试时显示）
    if [ $retries -gt 0 ]; then
      echo "Warning: Retry $retries/$max_retries failed for URL: $url (Status: ${http_status_code:-'N/A'})" >&2
    fi

    # 增加重试计数器并等待
    ((retries++))
    sleep "$retry_delay"
  done

  # 所有重试均失败，返回错误
  echo "Error: Failed to access URL '$url' after $max_retries retries. Last response:" >&2
  echo "$curl_output" | grep -v '^$' >&2  # 输出最后一次响应（非空行）
  return 1
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
  local download_url=$1
  local out_put=$2

  local http_status=$(check_url "$download_url" || echo 0)
  if [ $? -ne 0 ]; then
    error "maven-metadata cannot be found in nexus. url=$download_url (status: ${http_status:-unknown})"
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
    wget --timeout=3000 --tries=3 -nv --show-progress -P "$out_put" "$download_url"
  else
    wget --timeout=3000 --tries=3 -nv --show-progress -O "$out_put" "$download_url"
  fi
  info "-----------------------------------end-----------------------------------------------"
  sleep 1s
  return 0
}
