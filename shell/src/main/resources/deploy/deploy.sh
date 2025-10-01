#!/bin/bash

DEPLOYMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $DEPLOYMENT_DIR/../utils/common_util.sh
source $DEPLOYMENT_DIR/../config/parser-app.sh
source $DEPLOYMENT_DIR/../config/parser-server.sh
source $DEPLOYMENT_DIR/nexus_util.sh
HOSTNAMES=("data-server" "app-server" "core-server" "web-server")

# Display help
show_help() {
  cat <<EOF
Usage: deploy [options] [parameters]

Deployment tool, supports the following commands:

  deploy -help                 Display help information
  deploy -list                 List all services
  deploy -status {service-name} [-h {hostname,hostname}]
                               Check status of specified service, optionally specify hosts

  deploy -script [-v {version} -h {hostname,hostname}]
  deploy -s      [-v {version} -h {hostname,hostname}]
                               Execute script, optional version and hosts

  deploy -init {service-name} [-h {hostname,hostname}]
  deploy -i {service-name} [-h {hostname,hostname}]
                               Initialize service, optionally specify hosts

  deploy -tools {service-name} [-h {hostname,hostname}]
  deploy -t {service-name} [-h {hostname,hostname}]
                               Deploy tools, optionally specify hosts

  deploy -package {service-name} [-v {version} -c {primary} -g {default} -h {hostname,hostname} -r]
  deploy -p {service-name} [-v {version} -c {primary} -g {default} -h {hostname,hostname} -r]
                               Package service, optional version, instance, Cluster, hosts and restart

  deploy -rollback {service-name} [-v {version} -c {primary} -g {default} -h {hostname,hostname} -r]
  deploy -b {service-name} [-v {version} -c {primary} -g {default} -h {hostname,hostname} -r]
                               Rollback service, optional version, instance, Cluster, hosts and restart

Option descriptions:
  -h {hosts}      Specify hosts, multiple hosts separated by commas
  -v {version}    Specify version number
  -c {name}       Specify instance name, default primary
  -g {group}      Specify group, default default
  -r              Restart service after operation
EOF
}
# deploy script to server
function deploy_script() {
  info "going to deploy script to version [$DVERSION], hostName[$DHOST]"
  validate_service_name "$DSERVICE_NAME" || exit 1

  retrieve_version_from_meta $DSERVICE_NAME $DVERSION
  download_package_from_nexus $DSERVICE_NAME
  copy_install
}

function init_service(){
  DHOST="${DHOST:-$(HOSTNAME)}"
  info "going to init component[$DSERVICE_NAME] to version [$DVERSION], hostName=$DHOST"
  validate_service_name "$DSERVICE_NAME" || exit 1

  local language=$(get_service_config "$DSERVICE_NAME" "language")
  info "going to init component with language=$language"
  if [ ! -n "$language" ]; then
    echo "language not found"
  elif [ "$language" == "java" ]; then
    retrieve_version_from_meta $DSERVICE_NAME $DVERSION
    download_package_from_nexus $DSERVICE_NAME
  else
    retrieve_version_from_meta "tools" $DVERSION
    download_package_from_nexus "tools"
  fi
  copy_install
}

function restart_tools(){
  DHOST="${DHOST:-$(HOSTNAME)}"
  info "going restart tools[$DSERVICE_NAME], hostName=$DHOST"
  validate_service_name "$DSERVICE_NAME" || exit 1

  if [ -n "$DHOST" ]; then
    info "going to restart tools on the box[$DHOST]"
    call_remote_restart $DHOST
  else
    for ((i = 0; i < ${#HOSTNAMES[@]}; i++)); do
      info "going to restart tools on the box[${HOSTNAMES[i]}]"

      call_remote_restart ${HOSTNAMES[i]}
    done
  fi

}

function deploy_package() {
  info "going to deploy component[$DSERVICE_NAME] to version [$DVERSION], hostName=$DHOST"
  validate_service_name "$DSERVICE_NAME" || exit 1
  retrieve_version_from_meta $DSERVICE_NAME $DVERSION
  download_package_from_nexus $DSERVICE_NAME
  copy_install
}

function rollback_package() {
  info "going to rollback component[$DSERVICE_NAME] to version [$DVERSION], hostName=$DHOST"
}

function call_remote_restart() {
  DEPLOY_HOST=$1
  local CMD=". ~/.bash_profile;"$DEPLOYMENT_DIR/install.sh" $DCOMMAND $DSERVICE_NAME"

  green_line "run cmd in remote server[$(getUser)@$DEPLOY_HOST]: $CMD"
  if [[ "$(uname -s)" == "Linux"* ]]; then
    timeout 120 ssh -q $(getUser)@$DEPLOY_HOST "$CMD"
  else
    warn "please run cmd in Linux server."
  fi
}

check_service_status() {
  info "checking [$DSERVICE_NAME] status on host[$DHOST]"
}

# Validate if service name is valid
validate_service_name() {
  local service_name=$1
  if [ -z "$service_name" ]; then
    error "service name should not be empty" >&2
    return 1
  fi
  if ! service_exists $service_name; then
    error "service '$service_name' does not exist" >&2
    return 1
  fi
  return 0
}

# List all services
function list_services() {
  echo "Available services"
  echo "------------------------------------------------------------------------------------"
  printf "%-40s %-10s %-20s %-10s %-40s\n" \
    "Service" \
    "Language" \
    "Type" \
    "Region" \
    "Containers"
  get_all_services | while read -r service; do
    # Clean special characters and newlines from service name
    clean_service=$(echo "$service" | tr -d '\n\r')
    local language=$(get_service_config "$clean_service" "language" "unknown")
    local packageType=$(get_service_config "$clean_service" "packageType" "unknown")
    local containers=$(get_service_config "$clean_service" "containers" "{}")
    local activeRegion=$(get_service_config "$clean_service" "activeRegion" "unknown")

    printf "%-40s %-10s %-20s %-10s %-40s\n" \
      "$clean_service" \
      "$language" \
      "$packageType" \
      "$activeRegion" \
      "$containers"
  done
  echo "------------------------------------------------------------------------------------"
}

function copy_install() {
  local appInfo=$DSERVICE_NAME
  local language=$(get_service_config "$appInfo" "language")

  if [ -f "${DOWNLOAD_PACKAGE}" ]; then
    if [ -n "$DHOST" ]; then
      info "going to deploy package[${DOWNLOAD_PACKAGE}] to host[]"
      scp_package $language ${DOWNLOAD_PACKAGE} $DHOST
      call_remote_install $DHOST
    else
      for ((i = 0; i < ${#HOSTNAMES[@]}; i++)); do
        info "going to deploy package[${DOWNLOAD_PACKAGE}] to host[${HOSTNAMES[i]}]"
        scp_package $language ${DOWNLOAD_PACKAGE} ${HOSTNAMES[i]}
        call_remote_install ${HOSTNAMES[i]}
      done
    fi
  elif [ "$language" == "tools" ]; then
    info "tools package, no need to install"
  fi
}

function scp_package() {
  local language=$1
  local deploy_package=$2
  local deployHost=$3

  local repo="$(get_artifact_path)/${language}/"

  local file_name=$(basename "$DOWNLOAD_PACKAGE")
  REPO_FILE="${repo}${file_name}"
  info "Going to copy package to remote repository: $repo"
  info "↓------------------------------------------------------------------------------------------------------------------------------↓"
  info "                                  process package in remote server, hostName[$deployHost]                                    "
  info "↓                                ----------------------------------------------------------                                    ↓"
  if [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    timeout 60 ssh -q $(getUser)@$deployHost "mkdir -p $repo"
    scp $deploy_package $(getUser)@$deployHost:$repo

    debug "command: timeout 60 ssh -q $(getUser)@$deployHost 'mkdir -p $repo'"
    debug "command: scp $deploy_package $(getUser)@$deployHost:$repo"

    info "Copy package to remote repository: "
  else
    mkdir -p $repo
    cp -f $deploy_package $repo

    debug "command: cp -f $deploy_package $repo"
    info "Copy package to repository: "
  fi
  info "     package=$deploy_package"
  info "     repository=$(getUser)@$deployHost:$repo"
  info "     repository file=$(getUser)@$deployHost:$REPO_FILE"
}

function call_remote_install() {
  DEPLOY_HOST=$1
  local CMD=". ~/.bash_profile;"$DEPLOYMENT_DIR/install.sh" $DCOMMAND $DSERVICE_NAME $DEPLOY_VERSION $DINSTANCE $DCLUSTER $DRESTART $REPO_FILE"

  green_line "run cmd in remote server[$(getUser)@$DEPLOY_HOST]: $CMD"
  if [[ "$(uname -s)" == "Linux"* ]]; then
    timeout 120 ssh -q $(getUser)@$DEPLOY_HOST "$CMD"
  else
    warn "please run cmd in Linux server."
  fi
}

#http://core-server.luopc.com:8082/nexus/service/rest/repository/browse/maven-public/com/luopc/script/common/1.2.8-SNAPSHOT/1.2.8-20230530.143225-18/common-1.2.8-20230530.143225-18-bin.tar.gz
#http://core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/script/apps/1.2.8-SNAPSHOT/1.2.8-20230530.143225-18/apps-1.2.8-20230530.143225-18-bin.tar.gz
#http://core-server.luopc.com:8082/nexus/service/rest/repository/browse/maven-public/com/luopc/platform/cloud/config/vmagent/1.0-SNAPSHOT/1.0-20230601.234822-1/vmagent-1.0-20230601.234822-1-bin.tar.gz
# Get service host list
function get_service_hosts() {
  local appInfo=$1
  local env=$(getUser) # Default to uat environment

  # Get container configuration, like "data,code"
  local containers=$(get_service_config "$appInfo" "containers")
  # Convert to array
  IFS=',' read -ra container_types <<<"$containers"

  # Collect all servers
  local all_servers=()
  for type in "${container_types[@]}"; do
    # Get all servers of this type
    local servers=$(get_host_servers "$env.$type" | jq -r '.[]')
    all_servers+=($servers)
  done

  # Deduplicate and return
  printf '%s\n' "${all_servers[@]}" | sort -u | jq -R -s -c 'split("\n") | map(select(. != ""))'
}

#http://core-server.luopc.com:8082/nexus/service/rest/repository/browse/maven-public/com/luopc/platform/cloud/tools/platform-vmagent/1.0.0-SNAPSHOT/1.0.0-20230602.004149-1/platform-vmagent-1.0.0-20230602.004149-1.jar
# 从Nexus下载指定包
function download_package_from_nexus() {
  local appInfo=$1
  local module=${2:-}
  if [ -n "$PACKAGE_VERSION" ]; then
    # 获取包信息
    local package_path=$(get_service_config "$appInfo" "path")
    local artifact_group_id=$(get_service_config "$appInfo" "groupId")
    local artifact_id=$(get_service_config "$appInfo" "artifactId")
    local artifact_suffix=$(get_service_config "$appInfo" "packageType")
    local module=$(get_service_config "$appInfo" "module")

    # 验证包信息
    validate_package_info "$artifact_id"

    # 准备下载文件
    local download_file="$artifact_id-$PACKAGE_VERSION.$artifact_suffix"
    green_line "DOWNLOAD_INFO=[$package_path, $artifact_id, $artifact_group_id, $module, $artifact_suffix, $DEPLOY_VERSION, $PACKAGE_VERSION]"

    # 下载包
    download_from_nexus "$artifact_group_id" "$artifact_id" "$download_file"

    # 等待并验证下载
    wait_for_download "$download_file" || {
      error "package[$artifact_id] version [$PACKAGE_VERSION] cannot be found, please check your script."
      exit 1
    }

    DOWNLOAD_PACKAGE="$TEMP_DIR/$download_file"
    info "package is ready, path=$DOWNLOAD_PACKAGE"
  else
    exit 1
  fi
}


# Validate package information
function validate_package_info() {
  local artifact_id=$1
  [ -z "$artifact_id" ] && {
    error "artifact_id [$artifact_id] cannot be found in package info."
    exit 1
  }
}

# 从Nexus下载文件
function download_from_nexus() {
  local groupId=$1 module=$2 fileName=$3
  local download_url=$(get_nexus_url_by_version "$groupId" "$module" "$DEPLOY_VERSION" "$fileName")
  info "DOWNLOAD_URL=$download_url"

  local status=$(check_url "$download_url" || echo 0)
  if [ $? -ne 0 ]; then
    error "package cannot be found in nexus. fileName=$fileName, version=$DEPLOY_VERSION"
    exit 1
  fi

  info "going to download package from nexus, fileName=$fileName, TEMP_DIR=$TEMP_DIR"
  pull_from_nexus "$download_url" "$TEMP_DIR/"
}

# Wait for file download to complete
function wait_for_download() {
  local fileName=$1 wait_time=0 max_wait=15

  while ((wait_time <= max_wait)); do
    [ -f "$TEMP_DIR/$fileName" ] && return 0
    sleep 5
    wait_time=$((wait_time + 5))
    debug "file not ready, waiting ${wait_time}s"
  done

  return 1
}

#http://deploy:deploy@core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/script/common/1.2.8-SNAPSHOT/maven-metadata.xml
#http://deploy:deploy@core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/script/apps/1.2.8-SNAPSHOT/maven-metadata.xml
#http://deploy:deploy@core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/platform/cloud/config/cloud-platform-config/maven-metadata.xml
#http://deploy:deploy@core-server.luopc.com:8082/nexus/repository/maven-public/com/luopc/spring/learn/springboot/platform-vmagent/1.0.0-SNAPSHOT/maven-metadata.xml
# 从Nexus获取指定版本的元数据
function retrieve_version_from_meta() {
  local appInfo=$1
  local inputVersion=$2

  # 获取服务配置信息
  local artifactGroupId=$(get_service_config "$appInfo" "groupId")
  local artifactId=$(get_service_config "$appInfo" "artifactId")
  local artifactSuffix=$(get_service_config "$appInfo" "packageType")

  # 验证artifactId是否存在
  [ -z "${artifactId}" ] && {
    error "app_package [$artifactId] cannot be found in package info."
    exit 1
  }
  debug "PACKAGE_INFO=[$artifactId, $artifactGroupId, $artifactSuffix, $inputVersion]"

  # 处理不同版本类型
  case "$inputVersion" in
  *SNAPSHOT)
    process_snapshot_version "$artifactGroupId" "$artifactId" "$inputVersion"
    ;;
  "latest")
    process_latest_version "$artifactGroupId" "$artifactId"
    ;;
  "release")
    process_release_version "$artifactGroupId" "$artifactId"
    ;;
  *)
    process_specific_version "$artifactGroupId" "$artifactId" "$inputVersion"
    ;;
  esac
}

# Process SNAPSHOT version
function process_snapshot_version() {
  local groupId=$1 artifactId=$2 version=$3
  METADATA_URL=$(get_nexus_url_by_version "$groupId" "$artifactId" "$version" maven-metadata.xml)
  info "METADATA_URL=$METADATA_URL"

  if ! check_and_pull_metadata "$METADATA_URL" "$version"; then
    error "maven-metadata cannot be found in nexus. version=$version (status: ${status:-unknown})"
    exit 1
  fi

  DEPLOY_VERSION=$version
  local tmp_metadata="$TEMP_DIR/$version/maven-metadata.xml"
  if [ -f "$tmp_metadata" ]; then
    CLASSIFIER=$(awk '/<classifier>[^<]+<\/classifier>/{gsub(/<classifier>|<\/classifier>/,"",$1);print $1;exit;}' ${tmp_metadata})
    PACKAGE_VERSION=$(awk '/<value>[^<]+<\/value>/{gsub(/<value>|<\/value>/,"",$1);print $1;exit;}' ${tmp_metadata})
    if [[ -n "$CLASSIFIER" &&  -n "$PACKAGE_VERSION" ]]; then
      PACKAGE_VERSION=$PACKAGE_VERSION-$CLASSIFIER
    fi
    debug_metadata_status
  else
    error "maven-metadata cannot be found in nexus. version=$version"
    exit 1
  fi
}

# Process latest version
function process_latest_version() {
  local groupId=$1 artifactId=$2
  METADATA_URL=$(get_nexus_url "$groupId" "$artifactId" maven-metadata.xml)
  info "latest_version url = $METADATA_URL"

  if ! check_and_pull_metadata "$METADATA_URL"; then
    error "maven-metadata cannot be found in nexus. groupId=$1,artifactId=$2,version=latest"
    exit 1
  fi

  if [ -f "$TEMP_DIR/maven-metadata.xml" ]; then
    LATEST_VERSION=$(awk '/<latest>[^<]+<\/latest>/{gsub(/<latest>|<\/latest>/,"",$1);print $1;exit;}' $TEMP_DIR/maven-metadata.xml)
    DEPLOY_VERSION=$LATEST_VERSION

    if [[ $LATEST_VERSION == *SNAPSHOT ]]; then
      process_snapshot_version "$groupId" "$artifactId" "$LATEST_VERSION"
    else
      PACKAGE_VERSION=$LATEST_VERSION
      DEPLOY_VERSION=$LATEST_VERSION
    fi
    debug_metadata_status
  else
    error "maven-metadata cannot be found in nexus. groupId=$1,artifactId=$2,version=latest"
  fi
}

# Process release version
function process_release_version() {
  local groupId=$1 artifactId=$2
  METADATA_URL=$(get_nexus_url "$groupId" "$artifactId" maven-metadata.xml)

  if ! check_and_pull_metadata "$METADATA_URL"; then
    error "maven-metadata cannot be found in nexus. groupId=$1, artifactId=$2, version=release"
    exit 1
  fi
  if [ -f "$TEMP_DIR/maven-metadata.xml" ]; then
    PACKAGE_VERSION=$(awk '/<release>[^<]+<\/release>/{gsub(/<release>|<\/release>/,"",$1);print $1;exit;}' $TEMP_DIR/maven-metadata.xml)
    DEPLOY_VERSION=$PACKAGE_VERSION
    debug_metadata_status
  else
    error "maven-metadata cannot be found in nexus. groupId=$1, artifactId=$2, version=release"
    exit 1
  fi
}

# Process specific version
function process_specific_version() {
  local groupId=$1 artifactId=$2 version=$3
  debug "$version"

  local pom_url=$(get_nexus_url_by_version "$groupId" "$artifactId" "$version" "$artifactId-$version.pom")
  local status=$(check_url $pom_url || echo 0)
  if [ $? -ne 0 ]; then
    error "maven-metadata cannot be found in nexus. groupId=$1,artifactId=$2,version=$3"
    exit 1
  fi

  DEPLOY_VERSION=$version
  PACKAGE_VERSION=$version
  debug_metadata_status
}

# Check URL and pull metadata
function check_and_pull_metadata() {
  local status=$(pull_from_nexus "$1" "$TEMP_DIR/$2/")
  return 0
}

function get_artifact_path() {
  local config_path=$(get_common_config "artifactHome")
  local artifact_path=$(replace_path "$config_path")
  echo $artifact_path;
}

# Debug metadata status
function debug_metadata_status() {
  info "Getting metadata from nexus: $METADATA_URL, PACKAGE_VERSION=$PACKAGE_VERSION, DEPLOY_VERSION=$DEPLOY_VERSION"
}

# Initialize configuration
function init_config() {
  check_app_config_file
  check_jq
  # Check required commands
  check_command ssh
  check_command scp
  check_command curl
  check_command tar
  check_command jq
  check_command tr
}

# Main logic processing
main() {
  local uname=$(get_user)
  info "Running as user: $uname"
  if [ "$uname" == "root" ]; then
    error "Cannot be run with root account."
    exit 1
  fi

  # Initialize configuration
  init_config

  if [ $# -eq 0 ]; then
    show_help
    exit 1
  fi

  DCOMMAND=""
  DSERVICE_NAME=""
  DVERSION="latest"
  DHOST=""
  DINSTANCE="primary"
  DCLUSTER="default"
  DRESTART=0

  # Parse command line arguments
  while [ $# -gt 0 ]; do
    case "$1" in
    -help)
      DCOMMAND="help"
      shift
      ;;
    -list | -l)
      DCOMMAND="list"
      shift
      ;;
    -status)
      DCOMMAND="status"
      shift
      DSERVICE_NAME="$1"
      validate_service_name "$DSERVICE_NAME" || exit 1
      shift
      ;;
    -script | -s)
      DCOMMAND="script"
      DSERVICE_NAME="script"
      shift
      ;;
    -init | -i)
      DCOMMAND="init"
      shift
      DSERVICE_NAME="$1"
      shift
      ;;
    -tools | -t)
      DCOMMAND="tools"
      shift
      DSERVICE_NAME="$1"
      shift
      ;;
    -package | -p)
      DCOMMAND="package"
      shift
      DSERVICE_NAME="$1"
      shift
      ;;
    -rollback | -b)
      DCOMMAND="rollback"
      shift
      DSERVICE_NAME="$1"
      shift
      ;;
    -v)
      shift
      DVERSION="${1:-latest}"
      shift
      ;;
    -h)
      shift
      DHOST="$1"
      shift
      ;;
    -c)
      shift
      DINSTANCE="$1"
      shift
      ;;
    -g)
      shift
      DCLUSTER="$1"
      shift
      ;;
    -r)
      DRESTART=1
      shift
      ;;
    *)
      error "Error: Unknown option $1" >&2
      show_help >&2
      exit 1
      ;;
    esac
  done

  # Validate if command exists
  if [ -z "$DCOMMAND" ]; then
    error "Error: Must specify a command" >&2
    show_help >&2
    exit 1
  fi

  # Parse host list
  # Create temporary file
  TEMP_DIR=$(mk_temp "$(getRootPath)/tmp")
  # Execute corresponding command
  case "$DCOMMAND" in
  help)
    show_help
    ;;
  list)
    list_services
    ;;
  status)
    check_service_status
    ;;
  script)
    print_header
    info "Executing deployment script:"
    deploy_script
    print_footer
    ;;
  init)
    print_header
    info "Initializing service $DSERVICE_NAME:"
    info "  Service initialization completed"
    init_service
    print_footer
    ;;
  tools)
    print_header
    info "Deploying tools to service $DSERVICE_NAME:"
    restart_tools
    print_footer
    ;;
  package)
    print_header
    info "Packaging service $DSERVICE_NAME:"
    [ -n "$DVERSION" ] && info "  Version: $DVERSION"
    info "  Instance: $DINSTANCE"
    info "  Cluster: $DCLUSTER"
    [ $DRESTART -eq 1 ] && info "  Restart after operation: Yes"
    deploy_package
    info "  Service packaging completed"
    print_footer
    ;;
  rollback)
    print_header
    info "Rolling back service $DSERVICE_NAME:"
    [ -n "$DVERSION" ] && info "  Rollback to version: $DVERSION"
    info "  Instance: $DINSTANCE"
    info "  Cluster: $DCLUSTER"
    rollback_service
    print_footer
    ;;
  *)
    error "Error: Unknown command $DCOMMAND" >&2
    exit 1
    ;;
  esac
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf $TEMP_DIR
  fi
  exit 0
}

function deploy_path() {
  local package_path=$(get_service_config "$DSERVICE_NAME" "path")
  local artifactId=$(get_service_config "$DSERVICE_NAME" "artifactId")
  local target_dir=$(replace_path "${package_path}")
  echo "$target_dir/$artifactId"
}

function print_header() {
  echo -e "${GREEN}+-----------------------------------------------------------------------------------+${NC}"
  echo -e "${GREEN}|    APPLICATION:         ${DSERVICE_NAME:-$DCOMMAND}                                ${NC}"
  echo -e "${GREEN}|    APPLICATION_VERSION: $DVERSION                                                  ${NC}"
  echo -e "${GREEN}+-----------------------------------------------------------------------------------+${NC}"
}

function print_footer() {
  echo -e "${GREEN}+-----------------------------------------------------------------------------------+${NC}"
  echo -e "${GREEN}|    APPLICATION:         ${DSERVICE_NAME:-$DCOMMAND}                                ${NC}"
  echo -e "${GREEN}|    APPLICATION_PATH:    $(deploy_path)                                             ${NC}"
  echo -e "${GREEN}|    APPLICATION_VERSION: $DEPLOY_VERSION                                            ${NC}"
  echo -e "${GREEN}+-----------------------------------------------------------------------------------+${NC}"
}

# Start main logic
main "$@"
