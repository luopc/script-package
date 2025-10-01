#!/bin/bash

INSTALL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $INSTALL_DIR/../utils/common_util.sh
source $INSTALL_DIR/../config/parser-app.sh
source $INSTALL_DIR/../config/parser-server.sh

# Display help information
show_help() {
  cat << EOF
Usage: $0 <type> <serviceName> <resource_path> [version] [instance] [group] [restart]

Script to install jar packages locally, supports multiple operation types

Parameter description:
  <type>               Operation type (required): script|init|package|tools|rollback
  <serviceName>        Service name (required): mds|tbs|tqs...
  [version]            Version number: e.g., 6.1.10-SNAPSHOT (optional)
  [instance]           Instance type: master|slave|main|standby|backup|primary|secondary (optional, default: primary)
  [group]              Group name: must be default or start with group/node followed by numbers (optional, default: default)
  [restart]            Whether to restart: 0|1 (optional, default: 0)
  [resource_path]      Local jar package path (required): e.g., /c/tmp/xxx.jar

Examples:
  $0 script script /c/tmp/script-common-6.1.10.jar 6.1.10-SNAPSHOT primary default 0
  $0 package mds /c/tmp/market-data-service-6.1.10.jar 6.1.10-SNAPSHOT primary default 1
  $0 tools nexus /c/tmp/nexus-6.1.10.jar 6.1.10-SNAPSHOT primary default 1
EOF
}

# Initialize variables
type=""
serviceName=""
resourcePath=""
version=""
instance="primary"
cluster="default"
restart=0
TEMP_OUTPUT="/tmp"

# Parse positional parameters
parse_args() {
  # Check minimum parameter count
  if [ $# -lt 2 ]; then
    error "Error: Insufficient parameters" >&2
    show_help
    exit 1
  fi

  # Required parameters
  type="$1"
  serviceName="$2"

  # Optional parameters (assigned by position)
  if [ $# -ge 3 ]; then version="$3"; fi
  if [ $# -ge 4 ]; then instance="$4"; fi
  if [ $# -ge 5 ]; then cluster="$5"; fi
  if [ $# -ge 6 ]; then restart="$6"; fi
  if [ $# -ge 7 ]; then resourcePath="$7"; fi

  # Validate parameter value legality
  if [[ ! "$type" =~ ^(script|init|package|tools|rollback)$ ]]; then
    error "Error: Invalid type value, must be one of script|init|package|tools|rollback" >&2
    exit 1
  fi

  if [[ ! "$instance" =~ ^(primary|secondary|master|slave|main|standby|backup)$ ]]; then
    error "Error: Invalid instance value, must be one of master|slave|main|standby|backup|primary|secondary" >&2
    exit 1
  fi

  if [[ ! "$cluster" =~ ^(default|group[0-9]+|node[0-9]+)$ ]]; then
    error "Error: Invalid cluster value, must be default or start with group/node followed by numbers" >&2
    exit 1
  fi

  if [[ ! "$restart" =~ ^(0|1)$ ]]; then
    error "Error: Invalid restart value, must be 0 or 1" >&2
    exit 1
  fi

  # Validate if resource file exists (optimized)
  if [ -n "$resourcePath" ]; then  # 只有当resourcePath不为空时才检查
    if [ ! -f "$resourcePath" ]; then
      error "Unable to find source file at path: $resourcePath" >&2
      exit 1
    fi
  fi
}

# Display parameter information
show_params() {
  info "===== Operation Parameters ====="
  info "Operation Type: $type"
  info "Service Name: $serviceName"
  info "Resource Path: $resourcePath"
  info "Version: ${version:-Not specified}"
  info "Instance Type: $instance"
  info "Cluster: $cluster"
  info "Restart: $restart"
  info "=================================="
}

# Handle script type
function handle_script() {
  info "===== Executing script installation ====="
  # Get package information
  local package_path=$(get_service_config "$serviceName" "path")
  local artifactId=$(get_service_config "$serviceName" "artifactId")
  local packageType=$(get_service_config "$serviceName" "packageType")

  # Base path template
  local target_dir=$(replace_path "${package_path}")
  target_dir="$target_dir/$artifactId"
  info "target_dir=${target_dir}"

  create_target_dir "$target_dir"

  if [ -d $target_dir ]; then
    process_package_file "${packageType}" $resourcePath "$target_dir/version" $version
    update_soft_link "$target_dir" "version/$version"
  else
    error "script hasn't been initialized yet, please check you script. path=$target_dir"
  fi

  # Set execution permissions
  # chmod +x "$target_dir/$(basename "$resourcePath")"
  info "Script installed to: $target_dir"
}

# Handle init type
function handle_init() {
  info "===== Executing init installation ====="

  local language=$(get_service_config "$serviceName" "language" "unknown")
  local package_path=$(get_service_config "$serviceName" "path")
  local artifactId=$(get_service_config "$serviceName" "artifactId")
  local artifactSuffix=$(get_service_config "$serviceName" "packageType")
  local packageType=$(get_service_config "$serviceName" "packageType")
  local packageName=$(get_service_config "$serviceName" "packageName")

  info "package_path=${package_path}"
  local output_dir=$(replace_path "${package_path}")
  if [[ "$language" == "java" ]]; then
    output_dir="$output_dir/$serviceName"_"$instance"_"$cluster"
  elif [[ "$language" == "tools" ]]; then
    output_dir="$output_dir/$serviceName"
  else
    error "Error: Unsupported language type: $language" >&2
    exit 1
  fi

  info "output_dir=${output_dir}"
  create_target_dir "$output_dir"

  if [ ! -n "$language" ]; then
    echo "language not found"
  elif [ "$language" == "java" ]; then
    handle_package
  else
    process_package_file "${packageType}" $resourcePath "$TEMP_OUTPUT" "$artifactId"

    local target_dir="$TEMP_OUTPUT/$artifactId/$packageName"
    info "Copying files from :$target_dir"
    info "Copying files to   :$output_dir"

    if [[ -d $target_dir && -d $output_dir ]]; then
      process_package_file "file" "$target_dir/*" "$output_dir/"
    else
      error "package hasn't been initialized yet, please check you resource file. path=$output_dir"
    fi
  fi

  init_logDir $output_dir
  update_start_stop_link "$output_dir"
  if [ "$language" == "java" ]; then
    update_profile $output_dir
  fi
  if [[ -f $output_dir/updateConfig.sh ]]; then
      sh $output_dir/updateConfig.sh
  fi
  info "Initialization package installed to: $output_dir"
}

# Handle package type
function handle_package() {
  info "===== Executing package installation ====="
  local package_path=$(get_service_config "$serviceName" "path")
  local artifactId=$(get_service_config "$serviceName" "artifactId")
  local artifactSuffix=$(get_service_config "$serviceName" "packageType")
  local packageType=$(get_service_config "$serviceName" "packageType")
  info "package_path=${package_path}"

  # Base path template
  local target_dir=$(replace_path "${package_path}")
  target_dir="$target_dir/$serviceName"_"$instance"_"$cluster"
  info "target_dir=${target_dir}"

  if [ -d $target_dir ]; then
    create_target_dir "$target_dir/version/$version"
    if [ "$artifactSuffix" == "jar"  ]; then
      process_package_file "${packageType}" $resourcePath "$target_dir/version/$version" "$artifactId.$artifactSuffix"
    elif [ "$artifactSuffix" == "tar.gz"  ]; then
      process_package_file "tar.gz" $resourcePath "$TEMP_OUTPUT" "$artifactId"
      process_package_file "file" "$TEMP_OUTPUT/${artifactId}/*" "$target_dir/version/$version"
    fi
    update_soft_link "$target_dir" "version/$version"
    restart_service "$target_dir"
  else
    warn "package hasn't been initialized yet, please check you resource file. path=$target_dir"
  fi
  info "Package installed to: $target_dir"
}

# Handle tools type
handle_tools() {
  info "===== Executing tools installation ====="

  # Get package information
  local package_path=$(get_service_config "$serviceName" "path")
  local packageName=$(get_service_config "$serviceName" "packageName")

  # Base path template
  local target_dir=$(replace_path "${package_path}")
  target_dir="$target_dir/$packageName"
  info "target_dir=${target_dir}"

  if [ -d $target_dir ]; then
    restart=1
    restart_service "${target_dir}"
  else
    error "tools [$serviceName] hasn't been initialized yet, please check the path=$target_dir"
  fi

  info "Tools handle completed: $target_dir"
}

# Handle rollback type
handle_rollback() {
  info "===== Executing rollback operation ====="
  if [ -z "$version" ]; then
    info "Error: Rollback operation must specify version number" >&2
    exit 1
  fi

  target_dir="/usr/local/services/$serviceName/$cluster/$instance/packages/$version"
  if [ ! -d "$target_dir" ]; then
    info "Error: Version directory does not exist - $target_dir" >&2
    exit 1
  fi

  # Find jar package
  jar_file=$(find "$target_dir" -maxdepth 1 -name "*.jar" | head -n 1)
  if [ -z "$jar_file" ]; then
    info "Error: No jar package found in version directory - $target_dir" >&2
    exit 1
  fi

  # Restore link
  ln -sf "$jar_file" "/usr/local/services/$serviceName/$cluster/$instance/current.jar"
  info "Rolled back to version: $version"
  info "Currently using jar package: $jar_file"
}

# Restart service
restart_service() {
  if [ "$restart" -eq 1 ]; then
    info "===== Executing service restart ====="
    local service_path=$1

    # Try to execute restart script
    if [ -f "$service_path/restart.sh" ]; then
      "$service_path/restart.sh" || {
        info "Warning: Restart script execution failed, attempting manual restart"
        manual_restart $1
      }
    else
      manual_restart $1
    fi
  fi
}

update_start_stop_link() {
  local appHome=$1
  local scriptHome=$(get_common_config "scriptHome")
  scriptHome="$(replace_path "$scriptHome")/shell/current"
  info "Get scriptHome from config=$scriptHome"

  local start_script="$scriptHome/unix_scripts/start.sh"
  local stop_script="$scriptHome/unix_scripts/stop.sh"
  local query_script="$scriptHome/unix_scripts/query.sh"
  local restart_script="$scriptHome/unix_scripts/restart.sh"

  if [ -f "$start_script" ]; then
    if is_windows; then
      info "Windows system, copy script to $appHome"
      if ! cp "$start_script" "$appHome"; then
        error "Failed to copy start.sh from -> $start_script"
        return 1
      else
        cp "$stop_script" "$appHome"
        cp "$query_script" "$appHome"
        cp "$restart_script" "$appHome"
      fi
    else
      info "Linux system, create soft link to $appHome"
      create_unix_symlink_linux "${appHome}" "$start_script" "start.sh"
      create_unix_symlink_linux "${appHome}" "$stop_script" "stop.sh"
      create_unix_symlink_linux "${appHome}" "$query_script" "query.sh"
      create_unix_symlink_linux "${appHome}" "$restart_script" "restart.sh"
    fi
  else
    error "start_script not found: $start_script"
  fi

  if [[ "$(uname -s)" == "Linux"* ]]; then
    timeout 120 ssh -q $(getUser)@$HOSTNAME ". ~/.bash_profile; cd $APP_HOME; chmod 750 *.sh"
    debug "command: timeout 120 ssh -q $(getUser)@$HOSTNAME '. ~/.bash_profile; cd $APP_HOME; chmod 750 *.sh' "
  fi
}

# Windows专用方法：创建日志文件夹（如果logs不存在）
create_log_dir_windows() {
  local app_home="$1"
  local log_dir="$2"
  local original_pwd="$PWD"

  if ! cd "$app_home"; then
    error "Failed to change to application directory: $app_home"
    return 1
  fi

  # 如果logs目录不存在则创建
  if [ ! -d "logs" ]; then
    mkdir "logs" || {
      error "Failed to create logs directory in Windows"
      cd "$original_pwd"
      return 1
    }
    info "Created logs directory in Windows: $app_home/logs"
  fi

  cd "$original_pwd"
  debug "Returned to original directory: $original_pwd"
}

# 主方法：初始化日志目录（根据系统自动选择实现）
init_logDir() {
  local appHome=$1
  local logHome=$(get_common_config "logHome")
  local language=$(get_service_config "$serviceName" "language" "unknown")
  logHome=$(replace_path "$logHome")
  info "logHome=$logHome"

  local log_dir="$logHome/${language}/${serviceName}/$instance/$cluster"

  # 创建日志目录（通用）
  create_target_dir "$log_dir" || return 1

  # 根据系统选择实现
  if is_windows; then
    info "Windows system detected - creating logs directory"
    create_log_dir_windows "$appHome" "$log_dir" || return 1
  else
    info "Linux system detected - creating symbolic link"
    create_unix_symlink_linux "$appHome" "$log_dir" "logs" || return 1
  fi

  info "Initialized log directory: $log_dir"
}


##status=1(INSTANCE SHOULD START)status=0(INSTANCE SHOUT NOT START)
#export CURRENT_STATUS=1
#export CURRENT_INSTANCE=primary
#export CURRENT_GROUP=default
#export ARTIFACT_GROUP_ID=com.luopc.spring.learn.springboot
#export ARTIFACT_ID=spring-boot-micrometer
#export ARTIFACT_SUFFIX=.jar
function update_profile() {
  local APP_HOME="$1"

  local profile_file="$APP_HOME/instance.profile"
  local backup_file="$APP_HOME/instance.profile.backup.$(date +%Y%m%d_%H%M%S).txt"

  # Validate input parameters
  if [[ -z "$APP_HOME" ]]; then
    error "Error: APP_HOME parameter is required for update_profile function"
    return 1
  fi

  if [[ ! -d "$APP_HOME" ]]; then
    error "Error: APP_HOME directory does not exist: $APP_HOME"
    return 1
  fi

  # Get service configuration with error handling
  local language groupId artifactId artifactSuffix
  language=$(get_service_config "$serviceName" "language" "unknown")
  groupId=$(get_service_config "$serviceName" "groupId")
  artifactId=$(get_service_config "$serviceName" "artifactId")
  artifactSuffix=$(get_service_config "$serviceName" "packageType")
  jvmOptions=$(get_service_config "$serviceName" "jvmOptions")
  javaHome=$(get_service_config "$serviceName" "javaHome")

  # Validate required configuration values
  if [[ -z "$groupId" || -z "$artifactId" ]]; then
    error "Error: Missing required service configuration (groupId or artifactId) for service: $serviceName"
    return 1
  fi

  if [ -n "$javaHome" ]; then
    javaHome=$(replace_path "$javaHome")/bin/java
  fi

  info "Updating instance profile: $profile_file"

  # Create backup of existing profile if it exists
  if [[ -f "$profile_file" ]]; then
    info "Creating backup of existing profile: $backup_file"
    if ! cp "$profile_file" "$backup_file"; then
      error "Error: Failed to create backup of instance profile"
      return 1
    fi
  fi

  # Generate profile content in a single operation
  local profile_content
  profile_content=$(cat << EOF
# Instance Profile - Generated on $(date +'%Y-%m-%d %H:%M:%S')
# Service: $serviceName, Instance: ${instance:-primary}, Group: ${cluster:-default}
export CURRENT_STATUS=1
export CURRENT_APP="${serviceName}"
export CURRENT_INSTANCE="${instance:-primary}"
export CURRENT_GROUP="${cluster:-default}"
export ARTIFACT_GROUP_ID="${groupId}"
export ARTIFACT_ID="${artifactId}"
export LANGUAGE="${language}"
export ARTIFACT_SUFFIX="${artifactSuffix}"
export JVM_OPTIONS="${jvmOptions}"
export JDK_PATH="${javaHome}"
EOF
)

  # Write profile content atomically
  if ! echo "$profile_content" > "$profile_file"; then
    error "Error: Failed to write instance profile to $profile_file"
    # Restore backup if write failed and backup exists
    if [[ -f "$backup_file" ]]; then
      warn "Attempting to restore backup profile"
      cp "$backup_file" "$profile_file" || error "Error: Failed to restore backup profile"
    fi
    return 1
  fi

  # Verify the profile was written correctly
  if [[ ! -f "$profile_file" ]] || [[ ! -s "$profile_file" ]]; then
    error "Error: Profile file verification failed - file is missing or empty"
    return 1
  fi

  # Set appropriate permissions
  chmod 644 "$profile_file" 2>/dev/null || warn "Warning: Could not set profile file permissions"

  # Clean up old backup files (keep only last 5)
  find "$APP_HOME" -name "instance.profile.backup.*" -type f 2>/dev/null | \
    sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true

  info "Instance profile updated successfully"
  debug "Profile location: $profile_file"
  debug "Profile content preview:"
  debug "  CURRENT_APP: ${serviceName}"
  debug "  CURRENT_INSTANCE: ${instance:-primary}"
  debug "  CURRENT_GROUP: ${cluster:-default}"
  debug "  ARTIFACT_ID: ${artifactId}"

  return 0
}

# Manual service restart
manual_restart() {
  local service_path=$1

  # Find and stop service process
  pid=$(query_pid "$1")
  if [ -n "$pid" ]; then
    info "Stopping service process: $pid"
    kill -TERM "$pid"
    sleep 3
    # Check for remaining processes
    if ps -p "$pid" > /dev/null; then
      info "Force terminating remaining process"
      kill -KILL "$pid"
    fi
  fi

  # Start service
  info "Starting service..."
  if [ -f "$service_path/start.sh" ]; then
    "$service_path/start.sh" || {
      error "Start script execution failed"
      return 1
    }
  fi

  # Check startup status
  new_pid=$(query_pid "$1")
  if [ -n "$new_pid" ]; then
    green_line "Service started, process ID: $new_pid"
  else
    warn "Service startup failed, please check logs"
  fi
}

function query_pid() {
  local pidFile="$1/version/${APP_NAME:-default}.pid"
  local pidCmd="ps -ef|grep apps|grep $(getUser)|grep "$serviceName"|grep -v grep|grep -v sh|grep -v kill|awk '{print \$2}'"
  if [ -f "$pidFile" ]; then
    tpid=$(cat "$pidFile")
    if ! ps -p "$tpid" >/dev/null 2>&1; then
      rm -f "$pidFile"
      tpid=$(eval $pidCmd)
    fi
  else
    tpid=$(eval $pidCmd)
  fi
  echo $tpid
}

# Main function
main() {
  parse_args "$@"
  show_params
  TEMP_OUTPUT=$(mk_temp "$(getRootPath)/tmp")
  # Execute corresponding processing based on type
  case "$type" in
  script)
    handle_script
    ;;
  init)
    handle_init
    ;;
  package)
    handle_package
    ;;
  tools)
    handle_tools
    ;;
  rollback)
    handle_rollback
    ;;
  *)
    error "Error: Unsupported operation type - $type" >&2
    exit 1
    ;;
  esac
  if [[ -d "$TEMP_OUTPUT" ]]; then
    rm -rf $TEMP_OUTPUT
  fi
  info "===== Operation completed ====="
}

# Start main function
main "$@"
