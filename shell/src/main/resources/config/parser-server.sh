#!/bin/bash

SERVER_CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SERVER_CONFIG_FILE="$SERVER_CONFIG_DIR/config-server.json"
source $SERVER_CONFIG_DIR/../utils/common_util.sh

# 使用jq解析JSON配置
function parse_server_config() {
  local query="$1"
  jq -r "$query" "$SERVER_CONFIG_FILE" 2>/dev/null
}

# 获取 Nexus 配置的函数
function get_nexus_config() {
  parse_server_config ".nexus.$1"
}

# 获取通用配置
function get_common_config() {
  local key=$1
  local default=$2

  if [ -z "$key" ]; then
    parse_server_config ".common"
  else
    local value=$(parse_server_config ".common.$key")
    if [ "$value" == "null" ] || [ -z "$value" ]; then
      echo "$default"
    else
      echo "$value"
    fi
  fi
}

# 获取主机服务器列表
function get_host_servers() {
  local input=$1
  IFS='.' read -r env type <<< "$input"

  if [[ -z "$type" || "$type" == "all" ]]; then
    # 返回环境下的所有服务器
    parse_server_config ".hosts.$env[] | .[]" | jq -s '.'
  else
    # 返回特定类型的服务器
    parse_server_config ".hosts.$env.$type" | jq -s '.'
  fi
}

# 使用示例
function example_usage() {
  echo "Nexus Base URL: $(get_nexus_config 'baseUrl')"
  echo "Nexus Username: $(get_nexus_config 'username')"
  echo "Nexus Password: $(get_nexus_config 'password')"
  echo "Authenticated URL: $(get_nexus_auth_url)"

  # 或者获取完整配置
  echo "Complete Nexus config:"
  get_nexus_config
}

