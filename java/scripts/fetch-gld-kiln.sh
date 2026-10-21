#!/usr/bin/env bash
# Install io.github.leo-gan:gld-kiln-java:0.2.0 built from main commit REV.
# The Maven version stays 0.2.0. REV is the bulk numeric-list commit.
set -euo pipefail

TAG=0.2.0
REV=888ad8f91efe0d8c86e8763fb8fa328d3fb671b6
URL=https://github.com/leo-gan/gld-kiln-java.git
M2_REPO="${M2_REPO:-${HOME}/.m2/repository}"
JAR="${M2_REPO}/io/github/leo-gan/gld-kiln-java/${TAG}/gld-kiln-java-${TAG}.jar"
STAMP="${JAR}.rev"
if [[ -f "$JAR" && -f "$STAMP" && "$(cat "$STAMP")" == "$REV" ]]; then
  exit 0
fi

if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
  export JAVA_HOME="${JAVA_HOME:-${HOME}/.local/jdk-21}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

workdir="$(mktemp -d)"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

git init -q "$workdir/src"
git -C "$workdir/src" remote add origin "$URL"
git -C "$workdir/src" fetch --depth 1 origin "$REV"
git -C "$workdir/src" checkout --detach FETCH_HEAD
(
  cd "$workdir/src"
  ./gradlew --no-daemon publishToMavenLocal
)
test -f "$JAR"
printf '%s\n' "$REV" > "$STAMP"
