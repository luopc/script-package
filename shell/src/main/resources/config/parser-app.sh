#!/bin/bash

# JSON configuration parser utility
APP_CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
APP_CONFIG_FILE="$APP_CONFIG_DIR/config-app.json"
source $APP_CONFIG_DIR/../utils/common_util.sh

# 检查配置文件是否存在
function check_app_config_file() {
  if [ ! -f "$APP_CONFIG_FILE" ]; then
    error "Configuration file not found: $APP_CONFIG_FILE"
    exit 1
  fi
}

# 使用jq解析JSON配置
function parse_json_config() {
  local query="$1"
  jq -r "$query" "$APP_CONFIG_FILE" 2>/dev/null
}

# 获取所有服务名称
function get_all_services() {
  parse_json_config '.services | keys[]'
}

# 检查服务是否存在
function service_exists() {
  local app_name=$1
  local exists=$(parse_json_config ".services.\"$app_name\" | length")
  [ "$exists" -gt 0 ] 2>/dev/null
}

# 定义获取服务配置的函数
get_service_config() {
  local service_name=$(echo "$1" | tr -d '\n\r')
  local config_key="$2"
  local default_value="$3" # 可选的默认值参数
  # 检查必要参数
  if [ -z "$service_name" ] || [ -z "$config_key" ]; then
    echo "请提供服务名称和配置键" >&2
    return 1
  fi

  # 检查配置文件是否存在
  if [ ! -f "$APP_CONFIG_FILE" ]; then
    echo "配置文件 $APP_CONFIG_FILE 不存在" >&2
    return 1
  fi

  # 使用jq查询配置值
  local value=$(jq -r ".services[\"$service_name\"].\"$config_key\"" $APP_CONFIG_FILE)

  # 处理查询结果
  if [ "$value" = "null" ] || [ -z "$value" ]; then
    # 如果有默认值则返回默认值，否则返回空
    if [ -n "$default_value" ]; then
      echo "$default_value"
    else
      echo ""
    fi
  else
    echo "$value"
  fi
}

# 获取服务配置数组（逗号分隔）
function get_service_config_array() {
  local app_name=$1
  local key=$2
  parse_json_config ".services.\"$app_name\".$key[]?" | tr '\n' ','
}

# 获取Nexus配置
function get_nexus_config() {
  local key=$1
  local default=$2

  if [ -z "$key" ]; then
    parse_json_config ".nexus"
  else
    local value=$(parse_json_config ".nexus.$key")
    if [ "$value" == "null" ] || [ -z "$value" ]; then
      echo "$default"
    else
      echo "$value"
    fi
  fi
}

# 获取通用配置
function get_common_config() {
  local key=$1
  local default=$2

  if [ -z "$key" ]; then
    parse_json_config ".common"
  else
    local value=$(parse_json_config ".common.$key")
    if [ "$value" == "null" ] || [ -z "$value" ]; then
      echo "$default"
    else
      echo "$value"
    fi
  fi
}

# 获取模板配置
function get_template_config() {
  local key=$1
  local default=$2

  local value=$(parse_json_config ".templates.$key")
  if [ "$value" == "null" ] || [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# 验证配置完整性
function validate_service_config() {
  local app_name=$1

  local required_fields=("path" "groupId" "artifactId" "packageType")
  for field in "${required_fields[@]}"; do
    local value=$(get_service_config "$app_name" "$field")
    if [ -z "$value" ] || [ "$value" == "null" ]; then
      error "Service $app_name is missing required field: $field"
      return 1
    fi
  done

  return 0
}

# 示例用法
function example_usage() {
  echo "=== JSON Configuration Parser Examples ==="
  echo "get_all_services"
  echo "service_exists static-service"
  echo "get_service_config static-service path"
  echo "get_service_config trade-capture-service jvmOptions"
  echo "get_nexus_config baseUrl"
  echo "get_common_config javaHome"
  echo "get_template_config startSh"
}
