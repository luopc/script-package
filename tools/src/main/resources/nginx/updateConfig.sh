#!/bin/bash
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
APP_HOME=`dirname "$SCRIPT_PATH"`
# 配置参数
CONF_FILE="${APP_HOME}/conf/nginx-lb.conf" # 目标配置文件路径
TARGET_STR="lb.luopc.com"       # 要替换的原始字符串
SUFFIX=".luopc.com"              # 域名后缀

# 获取当前主机名
hostname=$(hostname)
echo "当前主机名: $hostname"

# 截取主机名前半部分（按 '-' 分割取第一个部分）
prefix=$(echo "$hostname" | cut -d'-' -f1)
if [ -z "$prefix" ]; then
  echo "错误: 无法从主机名中提取前缀"
  exit 1
fi
echo "提取的前缀: $prefix"

# 拼装新域名
new_domain="${prefix}${SUFFIX}"
echo "拼装的新域名: $new_domain"

# 检查配置文件是否存在
if [ ! -f "$CONF_FILE" ]; then
  echo "错误: 配置文件不存在 - $CONF_FILE"
  exit 1
fi

# 执行替换操作
# 使用sed替换，备份原始文件为 .bak
sed -i "s/${TARGET_STR};/${TARGET_STR} ${new_domain};/" "$CONF_FILE"
sed -i "s#rootPath#${APP_HOME}#" "$CONF_FILE"

# 检查替换结果
if grep -q "${TARGET_STR} ${new_domain};" "$CONF_FILE"; then
  echo "替换成功!"
  echo "替换详情:"
  echo "原始内容: ${TARGET_STR}"
  echo "替换后: ${TARGET_STR} ${new_domain};"
else
  echo "替换失败，请检查配置文件和目标字符串"
  exit 1
fi
