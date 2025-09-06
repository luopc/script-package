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
  <resource_path>      Local jar package path (required): e.g., /c/tmp/xxx.jar
  [version]            Version number: e.g., 6.1.10-SNAPSHOT (optional)
  [instance]           Instance type: master|slave|main|standby|backup|primary|secondary (optional, default: primary)
  [group]              Group name: must be default or start with group/node followed by numbers (optional, default: default)
  [restart]            Whether to restart: 0|1 (optional, default: 0)

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
group="default"
restart=0
TEMP_OUTPUT="/tmp"

# Parse positional parameters
parse_args() {
  # Check minimum parameter count
  if [ $# -lt 3 ]; then
    error "Error: Insufficient parameters" >&2
    show_help
    exit 1
  fi

  # Required parameters
  type="$1"
  serviceName="$2"
  resourcePath="$3"

  # Optional parameters (assigned by position)
  if [ $# -ge 4 ]; then version="$4"; fi
  if [ $# -ge 5 ]; then instance="$5"; fi
  if [ $# -ge 6 ]; then group="$6"; fi
  if [ $# -ge 7 ]; then restart="$7"; fi

  # Validate parameter value legality
  if [[ ! "$type" =~ ^(script|init|package|tools|rollback)$ ]]; then
    error "Error: Invalid type value, must be one of script|init|package|tools|rollback" >&2
    exit 1
  fi

  if [[ ! "$instance" =~ ^(primary|secondary|master|slave|main|standby|backup)$ ]]; then
    error "Error: Invalid instance value, must be one of master|slave|main|standby|backup|primary|secondary" >&2
    exit 1
  fi

  if [[ ! "$group" =~ ^(default|group[0-9]+|node[0-9]+)$ ]]; then
    error "Error: Invalid group value, must be default or start with group/node followed by numbers" >&2
    exit 1
  fi

  if [[ ! "$restart" =~ ^(0|1)$ ]]; then
    error "Error: Invalid restart value, must be 0 or 1" >&2
    exit 1
  fi

  # Validate if resource file exists
  if [ ! -f "$resourcePath" ]; then
    error "unable to find source from path - $resourcePath" >&2
    exit 1
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
  info "Group: $group"
  info "Restart: $restart"
  info "=================================="
}

# Handle script type
handle_script() {
  info "===== Executing script installation ====="
  # Get package information
  local package_path=$(get_service_config "$serviceName" "path")
  local artifactId=$(get_service_config "$serviceName" "artifactId")
  local packageType=$(get_service_config "$serviceName" "packageType")
  info "package_path=${package_path}"

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
handle_init() {
  info "===== Executing init installation ====="
  target_dir="/usr/local/services/$serviceName/$group/$instance/init"
  create_target_dir "$target_dir"

  # Copy file
  cp "$resourcePath" "$target_dir/" || {
    info "Error: File copy failed" >&2
    exit 1
  }

  # Record version information
  if [ -n "$version" ]; then
    info "$version" > "$target_dir/init_version.txt"
  fi
  info "Initialization package installed to: $target_dir"
}

# Handle package type
handle_package() {
  info "===== Executing package installation ====="
  local package_path=$(get_service_config "$serviceName" "path")
  local artifactId=$(get_service_config "$serviceName" "artifactId")
  local artifactSuffix=$(get_service_config "$serviceName" "packageType")
  local packageType=$(get_service_config "$serviceName" "packageType")
  info "package_path=${package_path}"

  # Base path template
  local target_dir=$(replace_path "${package_path}")
  target_dir="$target_dir/$artifactId"_"$instance"_"$group"
  info "target_dir=${target_dir}"

  create_target_dir "$target_dir"
  if [ -d $target_dir ]; then
    process_package_file "${packageType}" $resourcePath "$target_dir/version/$version" "$artifactId.$artifactSuffix"
    update_soft_link "$target_dir" "version/$version"
  else
    error "package hasn't been initialized yet, please check you resource file. path=$target_dir"
  fi

  info "Package installed to: $target_dir"
}

# Handle tools type
handle_tools() {
  info "===== Executing tools installation ====="
  target_dir="/usr/local/services/$serviceName/$group/$instance/tools"
  create_target_dir "$target_dir"

  # Copy file
  cp "$resourcePath" "$target_dir/" || {
    info "Error: File copy failed" >&2
    exit 1
  }

  # Record tool version
  if [ -n "$version" ]; then
    info "$(date +'%Y-%m-%d %H:%M:%S') $(basename "$resourcePath") $version" >> "$target_dir/version_history.log"
  fi
  info "Tools package installed to: $target_dir"
}

# Handle rollback type
handle_rollback() {
  info "===== Executing rollback operation ====="
  if [ -z "$version" ]; then
    info "Error: Rollback operation must specify version number" >&2
    exit 1
  fi

  target_dir="/usr/local/services/$serviceName/$group/$instance/packages/$version"
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
  ln -sf "$jar_file" "/usr/local/services/$serviceName/$group/$instance/current.jar"
  info "Rolled back to version: $version"
  info "Currently using jar package: $jar_file"
}

# Restart service
restart_service() {
  if [ "$restart" -eq 1 ]; then
    info "===== Executing service restart ====="
    service_path="/usr/local/services/$serviceName/$group/$instance"

    # Try to execute restart script
    if [ -f "$service_path/bin/restart.sh" ]; then
      "$service_path/bin/restart.sh" || {
        info "Warning: Restart script execution failed, attempting manual restart"
        manual_restart
      }
    else
      manual_restart
    fi
  fi
}

# Manual service restart
manual_restart() {
  service_path="/usr/local/services/$serviceName/$group/$instance"
  # Find and stop service process
  pid=$(ps -ef | grep "$serviceName" | grep -v grep | awk '{print $2}')
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
  nohup java -jar "$service_path/current.jar" > "$service_path/logs/console.log" 2>&1 &
  sleep 2

  # Check startup status
  new_pid=$(ps -ef | grep "$serviceName" | grep -v grep | awk '{print $2}')
  if [ -n "$new_pid" ]; then
    info "Service started, process ID: $new_pid"
  else
    info "Warning: Service startup failed, please check logs"
  fi
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

  # Handle restart
  restart_service

  info "===== Operation completed ====="
}

# Start main function
main "$@"
