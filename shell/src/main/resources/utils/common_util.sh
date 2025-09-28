#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m' # Cyan color
WHITE='\033[1;37m'
GREY='\033[1;90m'
NC='\033[0m' # No Color


# Check if jq is installed
function check_jq() {
    if ! command -v jq &> /dev/null; then
        error "jq is required for JSON parsing. Install with:"
        green_line "  Ubuntu/Debian: sudo apt-get install jq"
        green_line "  CentOS/RHEL: sudo yum install jq"
        green_line "  macOS: brew install jq"
        info ""
        exit 1
    fi
}

# Check if command exists
function check_command() {
    if ! command -v $1 &> /dev/null; then
        error "Command $1 is required but not installed."
    fi
}

function not_empty() {
  if [ -n "$1" ]; then
    echo "$2"
    exit 1
  fi
}

function should_empty() {
  if [ -z "$1" ]; then
    echo "$2"
    exit 1
  fi
}

function mk_temp() {
  TEMP_OUTPUT="$1/tmp.$(date +%s%N)"
  mkdir -p $TEMP_OUTPUT
  echo $TEMP_OUTPUT
}


# Create target directory
function create_target_dir() {
  local dir_path="$1"
  if [ ! -d "$dir_path" ]; then
    info "Creating directory: $dir_path"
    mkdir -p "$dir_path" || {
      error "Error: Cannot create directory $dir_path" >&2
      exit 1
    }
  fi
}

# File processing function
# If the input is a file type, copy the file to the target folder and rename it to file_name
# If the input is a jar type, copy the jar to the target folder and rename the jar file to file_name
# If the input is zip|gz type, first extract, then copy the files to the target folder and rename to file_name
function process_package_file() {
  local app_type=$1
  local input_path=$2
  local output_path=$3
  local file_name=$4

  # Validate input parameters
  if [[ -z "$input_path" || -z "$output_path" ]]; then
    error "Input path and output path cannot be empty"
    return 1
  fi

  # Create output directory
  mkdir -p "$output_path" || {
    error "Cannot create output directory: $output_path"
    return 1
  }

  case $app_type in
    file)
      info "Moving configuration file: $input_path -> $output_path"
      cp -rf $input_path $output_path || {
        error "Failed to move configuration file with command: cp -rf '$input_path' '$output_path'"
      }
      debug "Executed command: cp -rf '$input_path' '$output_path'"
      ;;
    jar)
      local dest_path="$output_path/${file_name:-$(basename "$input_path")}"
      info "Copying JAR file: $input_path -> $dest_path"
      cp -rf "$input_path" "$dest_path" || {
        error "Failed to copy JAR file"
        return 1
      }
      debug "Executed command: cp -rf '$input_path' '$dest_path' "
      ;;
    tar|zip|gz|tgz|tar.gz)
      # Validate if input file exists
      if [[ ! -f "$input_path" ]]; then
        error "Input file does not exist: $input_path"
        return 1
      fi

      info "Processing compressed file: $input_path"

      # Create temporary directory
      local temp_dir
      temp_dir=$(mk_temp "/tmp")
      if [[ $? -ne 0 || -z "$temp_dir" ]]; then
        error "Cannot create temporary directory"
        return 1
      fi

      # Extract based on file type
      local extract_success=false
      case "$app_type" in
        tar|tgz|tar.gz)
          info "Extracting tar format file to temporary directory: $temp_dir"
          if tar -zxf "$input_path" -C "$temp_dir" 2>/dev/null; then
            extract_success=true
          fi
          ;;
        zip)
          info "Extracting zip format file to temporary directory: $temp_dir"
          if command -v unzip >/dev/null 2>&1; then
            if unzip -q "$input_path" -d "$temp_dir" 2>/dev/null; then
              extract_success=true
            fi
          else
            warn "unzip command not found, trying other methods"
          fi
          ;;
        gz)
          info "Extracting gz format file to temporary directory: $temp_dir"
          local base_name
          base_name=$(basename "$input_path" .gz)
          if gunzip -c "$input_path" > "$temp_dir/$base_name" 2>/dev/null; then
            extract_success=true
          fi
          ;;
      esac

      # Check if extraction was successful
      if [[ "$extract_success" != "true" ]]; then
        error "Failed to extract file: $input_path"
        rm -rf "$temp_dir" 2>/dev/null
        return 1
      fi

      debug "File extracted successfully to: $temp_dir"

      # Check temporary directory contents
      local extracted_files
      extracted_files=$(find "$temp_dir" -mindepth 1 -maxdepth 1 2>/dev/null)

      if [[ -z "$extracted_files" ]]; then
        error "Temporary directory is empty after extraction"
        rm -rf "$temp_dir" 2>/dev/null
        return 1
      fi

      # Copy extracted content to target directory
      info "Copying extracted content to target directory: $output_path"

      # If file name is specified, rename
      if [[ -n "$file_name" ]]; then
        # Check if only one file/directory was extracted
        local file_count
        file_count=$(echo "$extracted_files" | wc -l)

        if [[ $file_count -eq 1 ]]; then
          # Only one file/directory, rename directly
          local source_item="$extracted_files"
          local dest_path="$output_path/$file_name"

          if ! cp -rf "$source_item" "$dest_path"; then
            error "Failed to copy and rename file: $source_item -> $dest_path"
            rm -rf "$temp_dir" 2>/dev/null
            return 1
          fi

          debug "Executed command: cp -rf '$source_item' '$dest_path'"
          info "File renamed to: $file_name"
        else
          # Multiple files, create directory named with file_name
          local dest_dir="$output_path/$file_name"
          mkdir -p "$dest_dir" || {
            error "Cannot create target directory: $dest_dir"
            rm -rf "$temp_dir" 2>/dev/null
            return 1
          }

          if ! cp -rf "$temp_dir"/* "$dest_dir"/; then
            error "Failed to copy multiple files to directory: $dest_dir"
            rm -rf "$temp_dir" 2>/dev/null
            return 1
          fi

          debug "Executed command: cp -rf '$temp_dir'/* '$dest_dir'/"
          info "Multiple files copied to directory: $file_name"
        fi
      else
        # No file name specified, copy all content directly
        if ! cp -rf "$temp_dir"/* "$output_path"/; then
          error "Failed to copy extracted content"
          rm -rf "$temp_dir" 2>/dev/null
          return 1
        fi

        debug "Executed command: cp -rf '$temp_dir'/* '$output_path'/"
        info "Extracted content copied to target directory"
      fi

      # Clean up temporary directory
      rm -rf "$temp_dir" 2>/dev/null
      debug "Temporary directory cleaned up: $temp_dir"

      info "Compressed file processing completed: $input_path -> $output_path"
      ;;
    *)
      error "Unsupported APP_INFO type: $app_type"
      return 1
      ;;
  esac
}

# Update symbolic link function
# Update symbolic link function - optimized for local execution
# Arguments: $1 - application path, $2 - package name, $3 - target host (optional)
# Returns: 0 on success, 1 on failure
function update_soft_link() {
  local app_path="$1"
  local package_name="$2"
  local target_host="${3:-}"
  local current_package="$app_path/$package_name"

  # Validate input parameters
  if [[ -z "$app_path" ]]; then
    error "Application path cannot be empty"
    return 1
  fi

  if [[ -z "$package_name" ]]; then
    error "Package name cannot be empty"
    return 1
  fi

  info "Application path: $app_path"
  info "Package name: $package_name"
  info "Current package: $current_package"
  if [[ -n "$target_host" ]]; then
    info "Target host: $target_host"
  else
    info "Execution mode: Local"
  fi

  # Determine execution mode (local vs remote)
  local is_remote=false
  if [[ -n "$target_host" && "$target_host" != "localhost" && "$target_host" != "$(hostname)" ]]; then
    is_remote=true
    info "Using remote execution mode for host: $target_host"
  else
    info "Using local execution mode"
  fi

  # Execute symbolic link operations
  if $is_remote; then
    _update_soft_link_remote "$app_path" "$package_name" "$target_host"
  else
    _update_soft_link_local "$app_path" "$package_name"
  fi
}

# Local symbolic link update implementation
# Arguments: $1 - application path, $2 - package name
# Returns: 0 on success, 1 on failure
function _update_soft_link_local() {
  local app_path="$1"
  local package_name="$2"
  local current_package="$app_path/$package_name"

  # Validate that target package directory exists
  if [[ ! -d "$current_package" ]]; then
    error "Target package directory does not exist: $current_package"
    return 1
  fi

  # Validate that application path exists
  if [[ ! -d "$app_path" ]]; then
    error "Application path does not exist: $app_path"
    return 1
  fi

  # Change to application directory
  local original_pwd="$PWD"
  if ! cd "$app_path"; then
    error "Failed to change to application directory: $app_path"
    return 1
  fi

  debug "Changed to directory: $app_path"

  # Handle existing links with backup
  if [[ -L "current" || -d "current" ]]; then
    info "Found existing 'current' link/directory"

    # Remove old previous if it exists
    if [[ -L "previous" || -d "previous" ]]; then
      info "Removing old 'previous' link/directory"
      if ! rm -rf "previous"; then
        error "Failed to remove old 'previous' link/directory"
        cd "$original_pwd"
        return 1
      fi
      debug "Successfully removed old 'previous'"
    fi

    # Move current to previous
    info "Moving 'current' to 'previous'"
    if ! mv "current" "previous"; then
      error "Failed to move 'current' to 'previous'"
      cd "$original_pwd"
      return 1
    fi
    debug "Successfully moved 'current' to 'previous'"
  fi

  # Create new symbolic link
  info "Creating new symbolic link: current -> $package_name"
  if ! ln -sf "$package_name" "current"; then
    error "Failed to create symbolic link: current -> $package_name"
    cd "$original_pwd"
    return 1
  fi

  # Verify the symbolic link was created correctly
  if [[ -L "current" ]]; then
    local link_target
    link_target="$(readlink "current")"
    if [[ "$link_target" == "$package_name" ]]; then
      info "Successfully created symbolic link: current -> $link_target"
    else
      warn "Symbolic link target mismatch. Expected: $package_name, Actual: $link_target"
    fi
  else
    error "Failed to verify symbolic link creation"
    cd "$original_pwd"
    return 1
  fi

  # Return to original directory
  cd "$original_pwd"
  debug "Returned to original directory: $original_pwd"

  info "Local symbolic link update completed successfully"
  return 0
}

# Remote symbolic link update implementation (fallback for compatibility)
# Arguments: $1 - application path, $2 - package name, $3 - target host
# Returns: 0 on success, 1 on failure
function _update_soft_link_remote() {
  local app_path="$1"
  local package_name="$2"
  local target_host="$3"
  local current_package="$app_path/$package_name"
  local user
  user="$(get_user)"

  # Build remote command
  local cmd="set -e; cd '$app_path' || exit 1;"

  # Handle existing links
  cmd="$cmd if [[ -L 'current' || -d 'current' ]]; then"
  cmd="$cmd   if [[ -L 'previous' || -d 'previous' ]]; then"
  cmd="$cmd     rm -rf 'previous';"
  cmd="$cmd   fi;"
  cmd="$cmd   mv 'current' 'previous';"
  cmd="$cmd fi;"

  # Create new link
  cmd="$cmd ln -sf '$package_name' 'current';"
  cmd="$cmd echo 'Symbolic link updated successfully';"

  info "Executing remote symbolic link update on $target_host"
  debug "Remote command: $cmd"

  # Execute remote command with timeout
  if ! timeout 120 ssh -q -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$target_host" "$cmd"; then
    error "Failed to update symbolic link on remote host: $target_host"
    return 1
  fi

  info "Remote symbolic link update completed successfully on $target_host"
  return 0
}

# Clean newlines and leading/trailing whitespace from text
function clean_text() {
  awk '{gsub(/\n/, ""); printf "%s", $0} END {print ""}' | awk '{gsub(/^[ \t]+|[ \t]+$/, ""); print}'
}

# Unified log format function
function log_message() {
    local level=$1
    local message=$2
    local color=$3
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local user=$(getUser)

    echo -e "${color}[${timestamp}] [${user}] ${level}: ${message} ${NC}"
}

function info() {
    log_message "INFO" "$1" "${NC}"
}

function debug() {
  if [[ "$(uname -s)" == CYGWIN* || "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    log_message "DEBUG" "$1" "${CYAN}"
  else
    log_message "DEBUG" "$1" "${GREY}"
  fi
}

function warn() {
  log_message "WARN" "$1" "${YELLOW}"
}

function error() {
  log_message "ERROR" "$1" "${RED}"
}

function green_line() {
  log_message "INFO" "$1" "${GREEN}"
}

function white_line() {
  log_message "INFO" "$1" "${WHITE}"
}

function cyan_line() {
  log_message "INFO" "$1" "${CYAN}"
}

function replace_path(){
  local replaced_path="$1"

  # Validate input
  if [[ -z "$replaced_path" ]]; then
    error "Path cannot be empty"
    return 1
  fi

  local rootPath
  local userPath

  rootPath="$(get_root_path)"
  userPath="$(get_user)"

  # Replace path variables
  replaced_path="$(replace_path_vars "$replaced_path" "ROOT_PATH" "$rootPath")"
  replaced_path="$(replace_path_vars "$replaced_path" "USER_PATH" "$userPath")"
  replaced_path="$(replace_path_vars "$replaced_path" "HOME" "$HOME")"
  replaced_path="$(replace_path_vars "$replaced_path" "PWD" "$PWD")"

  echo "$replaced_path"
}

# Replace path variables with specific variable name and value
# Arguments: $1 - original path, $2 - variable name, $3 - variable value
# Returns: path with variable replaced
function replace_path_vars() {
  local path="$1"
  local var_name="$2"
  local var_value="$3"

  # Replace variable placeholders in different formats
  path="${path//\{$var_name\}/$var_value}"      # {VAR_NAME}
  path="${path//\$$var_name/$var_value}"        # $VAR_NAME
  path="${path//\$\{$var_name\}/$var_value}"    # ${VAR_NAME}

  echo "$path"
}

#===============================================================================
# System Compatibility Functions
#===============================================================================

# Get current user in a cross-platform way
# Returns: current username
function get_user() {
  local user=""

  if [[ "$(uname -s)" == "Linux"* ]]; then
    user="${USER:-${LOGNAME:-unknown}}"
  elif [[ "$(uname -s)" == "Darwin"* ]]; then  # macOS
    user="${USER:-$(whoami)}"
  elif [[ "$(uname -s)" == CYGWIN* || "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    # Windows environments
    user="${USERNAME:-${USER:-uat}}"
  else
    user="${USER:-unknown}"
  fi

  echo "$user"
}

# Linux专用方法：创建软链接
create_unix_symlink_linux() {
  local app_home="$1"
  local link_dir="$2"
  local slink_name="$3"
  local original_pwd="$PWD"

  if ! cd "$app_home"; then
    error "Failed to change to application directory: $app_home"
    return 1
  fi

  # 删除已存在的文件或链接
  if [ -e "${slink_name}" ]; then
    rm -f "${slink_name}" || {
      error "Failed to remove existing logs file/link"
      cd "$original_pwd"
      return 1
    }
  fi

  # 创建软链接
  info "Creating symbolic link: $slink_name -> $link_dir"
  if ! ln -sf "$link_dir" "${slink_name}"; then
    error "Failed to create symbolic link: $slink_name -> $link_dir"
    cd "$original_pwd"
    return 1
  fi

  # 验证软链接
  if [[ -L "${slink_name}" ]]; then
    local link_target
    link_target="$(readlink "${slink_name}")"
    if [[ "$link_target" == "$link_dir" ]]; then
      info "Successfully created symbolic link: "${slink_name}" -> $link_target"
    else
      warn "Symbolic link target mismatch. Expected: $link_dir, Actual: $link_target"
    fi
  else
    error "Failed to verify symbolic link creation"
    cd "$original_pwd"
    return 1
  fi

  cd "$original_pwd"
  debug "Returned to original directory: $original_pwd"
}

readlink2() {
  local target="$1"

  # 如果不是符号链接，直接返回路径
  [ ! -h "$target" ] && echo "$target" && return

  # 提取符号链接指向的目标（兼容不同系统的 ls 输出格式）
  local link_target
  link_target=$(ls -ld -- "$target" 2>/dev/null | awk -F ' -> ' '{print $2}')

  # 如果解析失败，报错并退出
  if [ -z "$link_target" ]; then
    echo "Error: Failed to resolve symlink '$target'" >&2
    return 1
  fi

  # 获取符号链接所在的目录
  local symlink_dir
  symlink_dir=$(dirname -- "$target")

  # 如果目标路径是绝对的，直接返回；否则拼接目录
  if [[ "$link_target" == /* ]]; then
    echo "$link_target"
  else
    # 处理相对路径（如 ../target 或 ./target）
    echo "$symlink_dir/$link_target" | sed -e 's|/\./|/|g' -e 's|/\.\./|/../|g'
  fi
}

function pid_info() {
  local pid="$1"

  # 检查进程是否存在
  if ! ps -p "$pid" > /dev/null 2>&1; then
    echo "该PID[$1]不存在！！"
    return 1
  fi

  # 使用 /proc 文件系统获取进程信息，更可靠
  if [ ! -d "/proc/$pid" ]; then
    echo "该PID[$1]不存在！！"
    return 1
  fi

  # 从 /proc 获取信息
  local command=$(tr -d '\0' < "/proc/$pid/cmdline")
  if [ -f "$CMD_FILE" ]; then
    command=$(cat "$CMD_FILE")
  fi
  local user=$(stat -c "%U" "/proc/$pid")
  local cpu_usage=$(ps -p "$pid" -o pcpu= 2>/dev/null)
  local mem_usage=$(ps -p "$pid" -o pmem= 2>/dev/null)

  # 获取并格式化开始时间
  local start_time_secs=$(stat -c "%Y" "/proc/$pid")
  local friendly_start_time=$(date -d "@$start_time_secs" "+%Y年%m月%d日 %H:%M:%S")
  local start_time_relative=$(date -d "@$start_time_secs" "+%c")

  # 获取并格式化运行时间
  local start_time_epoch=$(stat -c "%Y" "/proc/$pid")
  local now_epoch=$(date +%s)
  local elapsed_seconds=$((now_epoch - start_time_epoch))

  # 将运行时间转换为更友好的格式
  local days=$((elapsed_seconds / 86400))
  local hours=$(( (elapsed_seconds % 86400) / 3600 ))
  local minutes=$(( (elapsed_seconds % 3600) / 60 ))
  local seconds=$((elapsed_seconds % 60))

  local friendly_run_time=""
  if [ $days -gt 0 ]; then
    friendly_run_time="${friendly_run_time}${days}天"
  fi
  if [ $hours -gt 0 ] || [ -n "$friendly_run_time" ]; then
    friendly_run_time="${friendly_run_time}${hours}小时"
  fi
  if [ $minutes -gt 0 ] || [ -n "$friendly_run_time" ]; then
    friendly_run_time="${friendly_run_time}${minutes}分"
  fi
  friendly_run_time="${friendly_run_time}${seconds}秒"

  local state=$(cat "/proc/$pid/status" | grep State | awk '{print $2}')
  # 将状态代码转换为更友好的描述
  case "$state" in
  "R") state_desc="运行中" ;;
  "S") state_desc="睡眠中" ;;
  "D") state_desc="不可中断的睡眠" ;;
  "Z") state_desc="僵尸进程" ;;
  "T") state_desc="已停止" ;;
  "t") state_desc="跟踪停止" ;;
  "X") state_desc="已死亡" ;;
  "I") state_desc="空闲" ;;
  *) state_desc="未知状态 ($state)" ;;
  esac

  local vsz=$(cat "/proc/$pid/status" | grep VmSize | awk '{print $2}')
  local rss=$(cat "/proc/$pid/status" | grep VmRSS | awk '{print $2}')

  # 格式化内存显示
  local vsz_friendly=""
  if [ $vsz -ge 1048576 ]; then
    vsz_friendly=$(echo "scale=2; $vsz / 1048576" | bc)" GB"
  elif [ $vsz -ge 1024 ]; then
    vsz_friendly=$(echo "scale=2; $vsz / 1024" | bc)" MB"
  else
    vsz_friendly="${vsz} KB"
  fi

  local rss_friendly=""
  if [ $rss -ge 1048576 ]; then
    rss_friendly=$(echo "scale=2; $rss / 1048576" | bc)" GB"
  elif [ $rss -ge 1024 ]; then
    rss_friendly=$(echo "scale=2; $rss / 1024" | bc)" MB"
  else
    rss_friendly="${rss} KB"
  fi

  info "进程PID: $pid"
  info "进程所属用户: $user"
  info "CPU占用率：${cpu_usage}%"
  info "内存占用率：${mem_usage}%"
  info "进程启动时间：$friendly_start_time"
  info "进程已运行：$friendly_run_time"
  info "进程状态：$state_desc"
  info "进程虚拟内存：$vsz_friendly"
  info "进程实际内存：$rss_friendly"
  info "进程命令：${command}..."
}

# Get root path based on operating system
# Returns: appropriate root path for the system
function get_root_path() {
  local root_path=""

  case "$(uname -s)" in
    Linux*)
      root_path=""
      ;;
    Darwin*)
      root_path="/usr/local"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      root_path="/c"
      ;;
    *)
      root_path="/tmp"
      ;;
  esac

  echo "$root_path"
}

# 检查操作系统类型
is_windows() {
  [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]
}

# Detect operating system
# Returns: OS name (linux, macos, windows, unknown)
function detect_os() {
  case "$(uname -s)" in
    Linux*)
      echo "linux"
      ;;
    Darwin*)
      echo "macos"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Legacy function aliases for backward compatibility
function getUser() {
  get_user
}
# get root path based on operating system
function getRootPath() {
  get_root_path
}
