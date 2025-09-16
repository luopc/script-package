#!/bin/bash

set -eo pipefail

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 打印帮助信息
usage() {
  echo "Usage: $0 [release|snapshot]"
  echo "  release    - Build and release a new version"
  echo "  snapshot   - Build and deploy a snapshot version (default)"
  exit 1
}

# 参数处理
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}No build type specified, defaulting to snapshot${NC}"
  BUILD_TYPE="snapshot"
else
  BUILD_TYPE=$(echo "$1" | tr '[:upper:]' '[:lower:]')
fi

# 参数校验
if [ "$BUILD_TYPE" != "release" ] && [ "$BUILD_TYPE" != "snapshot" ]; then
  echo -e "${RED}Error: Invalid build type argument${NC}"
  usage
fi

if [ "$BUILD_TYPE" = "release" ]; then
  echo -e "${GREEN}Building Release Version${NC}"

  # 清理工作区
  if ! git clean -f; then
    echo -e "${RED}Error: Failed to clean workspace${NC}"
    exit 1
  fi

  # 更新依赖版本
  mvn versions:use-latest-releases -Dincludes=com.luopc.platform.parent -DgenerateBackupPoms=false -DallowSnapshots=false
  mvn versions:use-latest-releases -Dincludes=com.luopc.platform.boot -DgenerateBackupPoms=false -DallowSnapshots=false

  # 检测版本变更
  echo -e "${YELLOW}Detecting version changes${NC}"
  # 检查是否有未提交的修改
  changes=$(git status --porcelain)
  if [ -n "$changes" ]; then
    echo -e "${GREEN}Changes detected, committing version updates${NC}"
    git add .

    if git diff --cached --quiet; then
      echo -e "${YELLOW}No changes to commit${NC}"
    else
      if ! git commit -m "#plugin - auto committed"; then
        echo -e "${RED}Error: Failed to commit version changes${NC}"
        exit 1
      else
        echo -e "${GREEN}Version changed and committed${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}No changes detected, skipping commit${NC}"
  fi
  VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | awk -v FS="-" '{print $1}')
  # 执行发布
  echo -e "${GREEN}Starting release build${NC}"
  if ! mvn -B clean release:prepare-with-pom release:perform \
    -DuseReleaseProfile=false \
    -Dmaven.javadoc.skip=true; then
    echo -e "${RED}Error: Release build failed${NC}"
    exit 1
  fi
  echo -e "${YELLOW}[INFO] released version is $VERSION ${NC}"
  echo -e "${GREEN}deploy -s -v $VERSION ${NC}"
elif [ "$BUILD_TYPE" = "snapshot" ]; then
  echo -e "${GREEN}Building Snapshot Version${NC}"

  if ! mvn -B clean deploy \
    -Dmaven.javadoc.skip=true; then
    echo -e "${RED}Error: Snapshot build failed${NC}"
    exit 1
  fi

  VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.6.0:exec)
  echo -e "${YELLOW}[INFO] current version is $VERSION ${NC}"
  echo -e "${GREEN}deploy -s -v $VERSION ${NC}"
else
  echo -e "${RED}Error: Invalid build type '$BUILD_TYPE'${NC}"
  usage
fi

