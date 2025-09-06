#!/bin/bash
# mvn versions:set -DoldVersion=* -DnewVersion=1.0.0-SNAPSHOT -DgenerateBackupPoms=false
set -e

BUILD_TYPE=$1

if [ "$BUILD_TYPE" = "release" ]; then
  echo "Build Release Version"
  git clean -f
  #mvn com.luopc:use-latest-version

  echo "Detecting auto version"
  DIFF=$(eval 'git diff --stat')
  echo "$DIFF"
  if [ -n "$DIFF" ]; then
    echo "change detected"
    git add .

    CHANGE=$(git status | grep "to be committed")
    if [ -n "$CHANGE" ]; then
      echo "Version Progressing"
      git commit -m "#plugin - auto committed"
    fi
  fi
  echo "release build starting"
  #mvn dependency:resolve dependency:revolve-plugin
  VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | awk -v FS="-" '{print $1}')
  mvn -B clean release:prepare-with-pom release:perform
  echo "release version is $VERSION"
else
  echo "Building Snapshot Version"
  mvn -B clean deploy
  VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.6.0:exec)
  echo "current version is $VERSION"
fi
