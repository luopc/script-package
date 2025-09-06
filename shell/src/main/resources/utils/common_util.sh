#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m' # Cyan color
WHITE='\033[1;37m'
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
      info "Copying configuration file: $input_path -> $output_path"
      cp -rf "$input_path" "$output_path" || {
        error "Failed to copy configuration file"
        return 1
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
      debug "Executed command: cp -rf '$input_path' '$dest_path'"
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

      debug "Created temporary directory: $temp_dir"

      # Extract based on file type
      local extract_success=false
      case "$app_type" in
        tar|tgz|tar.gz)
          info "Extracting tar format file to temporary directory"
          if tar -zxf "$input_path" -C "$temp_dir" 2>/dev/null; then
            extract_success=true
          fi
          ;;
        zip)
          info "Extracting zip format file to temporary directory"
          if command -v unzip >/dev/null 2>&1; then
            if unzip -q "$input_path" -d "$temp_dir" 2>/dev/null; then
              extract_success=true
            fi
          else
            warn "unzip command not found, trying other methods"
          fi
          ;;
        gz)
          info "Extracting gz format file to temporary directory"
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
    local color=$2
    local message=$3
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local user=$(getUser)

    echo -e "${color}[${timestamp}] [${user}] ${level}: ${message}${NC}"
}

function info() {
    log_message "INFO" "${NC}" "$1"
}

function debug() {
    log_message "DEBUG" "${BLUE}" "$1"
}

function warn() {
  log_message "WARN" "${YELLOW}" "$1"
}

function error() {
  log_message "ERROR" "${RED}" "$1"
}

function green_line() {
  log_message "INFO" "${GREEN}" "$1"
}

function white_line() {
  log_message "INFO" "${WHITE}" "$1"
}

function cyan_line() {
  log_message "INFO" "${CYAN}" "$1"
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

# Get root path based on operating system
# Returns: appropriate root path for the system
function get_root_path() {
  local root_path=""

  case "$(uname -s)" in
    Linux*)
      root_path="/opt"
      ;;
    Darwin*)
      root_path="/usr/local"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      root_path="/c/opt"
      ;;
    *)
      root_path="/tmp"
      ;;
  esac

  echo "$root_path"
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

function getRootPath() {
  get_root_path
}
