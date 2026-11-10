#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAVA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$JAVA_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

# Prefer user-local JDK 21+ and Maven
if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
  export JAVA_HOME="${JAVA_HOME:-${HOME}/.local/jdk-21}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi
if [[ -x "${HOME}/.local/maven/bin/mvn" ]]; then
  export PATH="${HOME}/.local/maven/bin:${PATH}"
fi
if [[ -z "${JAVA_HOME:-}" ]]; then
  for d in "${HOME}/.local"/jdk-*; do
    if [[ -x "$d/bin/java" ]]; then
      export JAVA_HOME="$d"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      break
    fi
  done
fi

bench_init_runner java jackson "$@"

if ! command -v java >/dev/null 2>&1; then
  echo "[ERROR] java not found. Run: ./scripts/install-host-requirements.sh java" >&2
  exit 1
fi
if ! command -v mvn >/dev/null 2>&1; then
  echo "[ERROR] mvn not found. Run: ./scripts/install-host-requirements.sh java" >&2
  exit 1
fi

# maven.compiler.release is 21. JDK 17 cannot compile this tree.
JAVA_VER="$(java -version 2>&1 | head -1)"
JAVA_MAJOR="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}' | tr -d ' \r' | cut -d. -f1)"
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 21 ]]; then
  echo "[ERROR] JDK 21+ required (found: ${JAVA_VER:-unknown}). Run: ./scripts/install-host-requirements.sh java" >&2
  exit 1
fi
echo "[INFO] Building Java benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $JAVA_VER"
cd "$JAVA_DIR"

export PROTOC="${PROTOC:-$(command -v protoc || true)}"
if [[ -x "${HOME}/.local/bin/protoc" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  export PROTOC="${HOME}/.local/bin/protoc"
fi

bash "$SCRIPT_DIR/fetch-gld-kiln.sh"
mvn -q -DskipTests package

JAR="$JAVA_DIR/target/serializer-benchmark-java-1.0.0-SNAPSHOT.jar"
if [[ ! -f "$JAR" ]]; then
  JAR="$(ls -1 "$JAVA_DIR"/target/serializer-benchmark-java-*.jar 2>/dev/null | grep -v original | head -1)"
fi
if [[ ! -f "$JAR" ]]; then
  echo "[ERROR] shaded jar not found under target/" >&2
  exit 1
fi

JAVA_ARGS=("--reps" "$REPS" "--log-dir" "$LOG_DIR")
if [[ -n "$FILTER_SER" ]]; then
  JAVA_ARGS+=("--serializer" "$FILTER_SER")
fi
if [[ -n "$FILTER_DATA" ]]; then
  JAVA_ARGS+=("--data" "$FILTER_DATA")
fi

# Kryo / FST need reflective access on JDK 21.
JAVA_OPTS="${JAVA_OPTS:-} --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/java.nio=org.apache.arrow.memory.core,ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.misc=ALL-UNNAMED"
echo "[INFO] Running: java $JAVA_OPTS -jar $JAR ${JAVA_ARGS[*]}"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" "${JAVA_ARGS[@]}"

bench_finish_runner Java
