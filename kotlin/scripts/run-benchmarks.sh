#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOTLIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$KOTLIN_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

# Prefer user-local JDK 21+
if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
  export JAVA_HOME="${JAVA_HOME:-${HOME}/.local/jdk-21}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
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

bench_init_runner kotlin kotlinx-json "$@"

if ! command -v java >/dev/null 2>&1; then
  echo "[ERROR] java not found. Run: ./scripts/install-host-requirements.sh kotlin" >&2
  exit 1
fi

JAVA_VER="$(java -version 2>&1 | head -1)"
# jvmToolchain(21). JDK 17 cannot satisfy that toolchain.
JAVA_MAJOR="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}' | tr -d ' \r' | cut -d. -f1)"
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 21 ]]; then
  echo "[ERROR] JDK 21+ required (found: ${JAVA_VER:-unknown}). Run: ./scripts/install-host-requirements.sh kotlin" >&2
  exit 1
fi
echo "[INFO] Building Kotlin benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $JAVA_VER"
cd "$KOTLIN_DIR"

GRADLEW="$KOTLIN_DIR/gradlew"
if [[ ! -x "$GRADLEW" ]]; then
  echo "[ERROR] gradle wrapper missing at $GRADLEW" >&2
  exit 1
fi

"$GRADLEW" -q shadowJar -x test

# shadowJar writes *-all.jar. The plain jar has no Main-Class.
JAR="$(ls -1 "$KOTLIN_DIR"/build/libs/serializer-benchmark-kotlin-*-all.jar 2>/dev/null | head -1 || true)"
if [[ ! -f "$JAR" ]]; then
  JAR="$(ls -1 "$KOTLIN_DIR"/build/libs/serializer-benchmark-kotlin-*.jar 2>/dev/null | grep -v -E 'plain|sources|javadoc' | head -1 || true)"
fi
if [[ ! -f "$JAR" ]]; then
  echo "[ERROR] shaded jar not found under build/libs/" >&2
  exit 1
fi

KT_ARGS=("--reps" "$REPS" "--log-dir" "$LOG_DIR")
if [[ -n "$FILTER_SER" ]]; then
  KT_ARGS+=("--serializer" "$FILTER_SER")
fi
if [[ -n "$FILTER_DATA" ]]; then
  KT_ARGS+=("--data" "$FILTER_DATA")
fi

JAVA_OPTS="${JAVA_OPTS:-} --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.nio=org.apache.arrow.memory.core,ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED"
echo "[INFO] Running: java $JAVA_OPTS -jar $JAR ${KT_ARGS[*]}"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" "${KT_ARGS[@]}"

bench_finish_runner Kotlin
