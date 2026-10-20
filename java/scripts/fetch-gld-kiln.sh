#!/usr/bin/env bash
# Install io.github.leo-gan:gld-kiln-java:0.2.0 from the GitHub tag into the local Maven repo.
set -euo pipefail

TAG=0.2.0
URL=https://github.com/leo-gan/gld-kiln-java.git
M2_REPO="${M2_REPO:-${HOME}/.m2/repository}"
JAR="${M2_REPO}/io/github/leo-gan/gld-kiln-java/${TAG}/gld-kiln-java-${TAG}.jar"
if [[ -f "$JAR" ]]; then
  exit 0
fi

if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
  export JAVA_HOME="${JAVA_HOME:-${HOME}/.local/jdk-21}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

workdir="$(mktemp -d)"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

git clone --depth 1 --branch "$TAG" "$URL" "$workdir/src"
(
  cd "$workdir/src"
  ./gradlew --no-daemon publishToMavenLocal
)
test -f "$JAR"
