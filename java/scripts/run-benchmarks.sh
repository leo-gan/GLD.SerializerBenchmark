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
# Also pick any jdk under ~/.local/jdk*
if [[ -z "${JAVA_HOME:-}" ]]; then
  for d in "${HOME}/.local"/jdk-*; do
    if [[ -x "$d/bin/java" ]]; then
      export JAVA_HOME="$d"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      break
    fi
  done
fi

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/java}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event (smoke default: message)"
    exit 1
    ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-jackson}"
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_LANGUAGE=java

# Library run config from master config (data_model_v2.smoke_run_config / default_run_config).
# Caller may override with BENCHMARK_RUN_CONFIG=...
bench_export_run_config "$MODE"

if ! command -v java >/dev/null 2>&1; then
  echo "[ERROR] java not found. Run: ./scripts/install-host-requirements.sh java" >&2
  exit 1
fi
if ! command -v mvn >/dev/null 2>&1; then
  echo "[ERROR] mvn not found. Run: ./scripts/install-host-requirements.sh java" >&2
  exit 1
fi

# Require Java 17+
JAVA_VER="$(java -version 2>&1 | head -1)"
echo "[INFO] Building Java benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $JAVA_VER"
cd "$JAVA_DIR"

# Ensure protoc on PATH for protobuf-maven-plugin
export PROTOC="${PROTOC:-$(command -v protoc || true)}"
if [[ -x "${HOME}/.local/bin/protoc" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  export PROTOC="${HOME}/.local/bin/protoc"
fi

mvn -q -DskipTests package

JAR="$JAVA_DIR/target/serializer-benchmark-java-1.0.0-SNAPSHOT.jar"
if [[ ! -f "$JAR" ]]; then
  # shade may produce original + shaded; find the shaded jar
  JAR="$(ls -1 "$JAVA_DIR"/target/serializer-benchmark-java-*.jar 2>/dev/null | grep -v original | head -1)"
fi
if [[ ! -f "$JAR" ]]; then
  echo "[ERROR] shaded jar not found under target/" >&2
  exit 1
fi

ARGS=("--reps" "$REPS" "--log-dir" "$LOG_DIR")
[[ -n "$FILTER_SER" ]] && ARGS+=("--serializer" "$FILTER_SER")
[[ -n "$FILTER_DATA" ]] && ARGS+=("--data" "$FILTER_DATA")

export LOG_DIR
# Kryo / FST need reflective access on JDK 17+
JAVA_OPTS="${JAVA_OPTS:-} --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED"
echo "[INFO] Running: java $JAVA_OPTS -jar $JAR ${ARGS[*]}"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" BENCHMARK_LANGUAGE=java \
      PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] Java logs in $LOG_DIR"
