#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：获取nginx最新版本
get_latest_nginx_version() {
  log_info "正在获取nginx最新版本..."

  # 方法1：尝试从下载页面获取
  version1=$(curl -s https://nginx.org/en/download.html | \
    grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | \
    head -1 2>/dev/null)

  # 方法2：从下载目录获取（备用）
  version2=$(curl -s https://nginx.org/download/ | \
    grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | \
    sort -V | tail -1 2>/dev/null)

  # 选择可用的版本号
  if [ -n "$version1" ]; then
    echo "$version1"
  elif [ -n "$version2" ]; then
    echo "$version2"
  else
    echo "error"
  fi
}

# 函数：验证版本号格式
validate_version() {
  local version=$1
  if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  else
    return 1
  fi
}

# 函数：检查前置依赖
check_dependencies() {
  local dependencies=(
    "gcc"
    "make"
    "wget"
    "tar"
    "curl"
    "zlib"
    "zlib-devel"
    "pcre-devel"
    "gcc-c++"
    "libtool"
    "openssl"
    "openssl-devel"
  )
  local missing=()

  log_info "检查系统依赖..."

  for pkg in "${dependencies[@]}"; do
    if ! rpm -q "$pkg" &> /dev/null && ! dpkg -s "$pkg" &> /dev/null; then
      missing+=("$pkg")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_error "缺少以下依赖: ${missing[*]}"
    log_warning "尝试自动安装依赖..."

    # 尝试自动安装依赖
    if command -v yum &> /dev/null; then
      sudo yum install -y "${missing[@]}" || {
        log_error "依赖安装失败，请手动安装"
        return 1
      }
    elif command -v apt-get &> /dev/null; then
      sudo apt-get install -y "${missing[@]}" || {
        log_error "依赖安装失败，请手动安装"
        return 1
      }
    else
      log_error "无法识别的包管理器，请手动安装依赖"
      return 1
    fi
  fi

  log_success "所有依赖都已安装"
  return 0
}

# 函数：安装Nginx
install_nginx() {
  local version=$1
  local current_dir=$(pwd)
  local package_dir="${current_dir}/package"
  local version_dir="${current_dir}/version"
  local nginx_dir="${version_dir}/nginx-${version}"

  # 0. 检查是否已安装该版本
  log_info "检查是否已安装nginx-${version}..."
  if [ -d "$nginx_dir" ]; then
    log_warning "nginx-${version} 已经安装在 ${nginx_dir}"
    log_info "更新current软链接..."

    # 更新current软链接
    if [ -L "${current_dir}/current" ]; then
      rm -f "${current_dir}/current"
    fi
    ln -sf "$nginx_dir" "${current_dir}/current"

    log_success "current软链接已更新指向nginx-${version}"
    return 0
  fi

  # 1. 确保目录存在
  mkdir -p "$package_dir"
  mkdir -p "$version_dir"

  # 2. 检查是否已下载源码包
  local package_path="${package_dir}/nginx.tar.gz"
  local nginx_url="https://nginx.org/download/nginx-${version}.tar.gz"

  log_info "检查nginx-${version}源码包..."
  if [ ! -f "${package_dir}/nginx-${version}.tar.gz" ]; then
    log_info "下载nginx ${version}..."
    if ! wget "$nginx_url" -O "${package_dir}/nginx-${version}.tar.gz"; then
      log_error "下载Nginx失败: ${nginx_url}"
      return 1
    fi
  else
    log_success "已找到nginx-${version}.tar.gz，跳过下载"
  fi

  # 3. 检查是否已解压
  log_info "检查是否已解压..."
  if [ ! -d "${package_dir}/nginx-${version}" ]; then
    log_info "解压nginx源码包..."
    if ! tar -zxvf "${package_dir}/nginx-${version}.tar.gz" -C "$package_dir"; then
      log_error "解压Nginx失败"
      return 1
    fi
  else
    log_success "已解压，跳过此步骤"
  fi

  # 4. 进入源码目录
  local src_dir="${package_dir}/nginx-${version}"
  cd "$src_dir" || {
    log_error "无法进入源码目录: ${src_dir}"
    return 1
  }

  # 5. 配置Nginx
  local conf_with=(
    --prefix="$nginx_dir"
    --with-http_ssl_module
    --with-http_stub_status_module
    --with-http_gzip_static_module
  )
  if ! ./configure "${conf_with[@]}"; then
    log_error "配置Nginx失败"
    return 1
  fi

  # 6. 编译安装
  log_info "编译安装Nginx..."
  make && make install || {
    log_error "编译安装Nginx失败"
    return 1
  }

  # 7. 返回原始目录
  cd "$current_dir" || return 1

  # 8 ggplot2::geom_sf(data = china_sf) + ggplot2::coord_sf() + ggplot2::theme_minimal() +
  #   ggplot2::theme(axis.text = ggplot2::element_blank(),
  #                  axis.title = ggplot2::element_blank(),
  #                  panel.grid = ggplot2::element_blank()) +
  #   ggplot2::geom_sf(data = sf_points, color = "red", size = 3) +
  #   ggplot2::ggtitle("地震震中分布图") +
  #   ggplot2::scale_fill_gradient(low = "lightyellow", high = "darkred", name = "震级") +
  #   ggplot2::guides(size = FALSE). 创建current软链接
  log_info "创建current软链接..."
  if [ -L "current" ]; then
    rm -f "current"
  fi
  ln -sf "$nginx_dir" "current"

  log_success "Nginx ${version} 安装成功!"

  # 9. 尝试启动Nginx
  if [ -f "start.sh" ]; then
    log_info "尝试启动Nginx..."
    ./start.sh
  else
    log_warning "未找到start.sh脚本，请手动启动"
  fi

  return 0
}

# 主程序
main() {
  # 0. 检查系统依赖
  if ! check_dependencies; then
    exit 1
  fi

  # 1. 处理版本参数
  version="$1"

  if [ -z "$version" ]; then
    log_info "未指定版本，尝试获取最新版本..."
    version=$(get_latest_nginx_version)

    if ! validate_version "$version"; then
      log_error "无法获取有效的Nginx版本"
      exit 1
    fi

    log_success "将使用最新版本: ${version}"
  else
    if ! validate_version "$version"; then
      log_error "无效的版本格式，请使用类似1.24.0的格式"
      exit 1
    fi
  fi

  log_info "=================================="
  log_info "开始安装Nginx ${version}版本"
  log_info "=================================="

  # 2. 调用安装函数
  if install_nginx "$version"; then
    log_success "=================================="
    log_success "Nginx ${version} 安装完成"
    log_success "=================================="
  else
    log_error "=================================="
    log_error "Nginx ${version} 安装失败"
    log_error "=================================="
    exit 1
  fi
}

# 执行主程序
main "$@"
