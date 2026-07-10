#!/usr/bin/env bash
set -e

# Modes / seed from config/benchmark_config.yaml
# Suite is Data Model v2 only (message/document/telemetry/strings/event).
IMAGE_NAME="python-serializer-benchmark"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

# Optional override: path to run-config YAML (host path mounted as /app/config/...).
RUN_CONFIG_HOST="${BENCHMARK_RUN_CONFIG:-$PROJECT_ROOT/config/library/default.yaml}"
if [[ "${1:-}" == "smoke" ]]; then
  RUN_CONFIG_HOST="${BENCHMARK_RUN_CONFIG:-$PROJECT_ROOT/config/library/smoke.yaml}"
fi
# Container path for the same file under the config/ mount.
RUN_CONFIG_CONTAINER="/app/config/library/$(basename "$RUN_CONFIG_HOST")"

print_usage() {
    echo "Usage: ./scripts/run-benchmarks.sh [smoke | all-single | full | research | custom]"
    echo ""
    echo "Modes (from config/benchmark_config.yaml):"
    echo "  smoke | all-single | full | research — reps from modes.<name>.repetitions"
    echo "  custom — Manual: ./scripts/run-benchmarks.sh custom <reps> [serializerFilter] [dataFilter]"
    echo ""
    echo "Data Model v2 (env):"
    echo "  BENCHMARK_RUN_CONFIG=path    (run config YAML; default library/default.yaml,"
    echo "                               smoke uses library/smoke.yaml)"
    echo "  Type filters: message | document | telemetry | strings | event"
}

echo "[INFO] Ensuring Docker image is up to date..."
docker build -t $IMAGE_NAME -f "$SCRIPT_DIR/../Dockerfile" "$PROJECT_ROOT"

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"

MODE="${1:-}"
case "$MODE" in
    smoke)
        REPS="$(bench_mode_reps smoke)"
        echo "[INFO] Running Smoke Test v2 ($REPS reps) run_config=$RUN_CONFIG_HOST..."
        docker run --rm \
          -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -e BENCHMARK_DATA_MODEL=v2 \
          -e BENCHMARK_RUN_CONFIG="$RUN_CONFIG_CONTAINER" \
          -e LOG_DIR=/app/logs \
          -v "$LOG_DIR":/app/logs \
          -v "$PROJECT_ROOT/schemas":/app/schemas \
          -v "$PROJECT_ROOT/config":/app/config:ro \
          $IMAGE_NAME "$REPS"
        ;;
    all-single|full|research)
        REPS="$(bench_mode_reps "$MODE")"
        echo "[INFO] Running $MODE v2 ($REPS reps) [config modes.$MODE]..."
        docker run --rm \
          -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -e BENCHMARK_DATA_MODEL=v2 \
          -e BENCHMARK_RUN_CONFIG=/app/config/library/default.yaml \
          -e LOG_DIR=/app/logs \
          -v "$LOG_DIR":/app/logs \
          -v "$PROJECT_ROOT/schemas":/app/schemas \
          -v "$PROJECT_ROOT/config":/app/config:ro \
          $IMAGE_NAME "$REPS"
        ;;
    custom)
        shift
        echo "[INFO] Running Custom Benchmark (Args: $*) v2..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -e BENCHMARK_DATA_MODEL=v2 \
          -e BENCHMARK_RUN_CONFIG=/app/config/library/default.yaml \
          -e LOG_DIR=/app/logs -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas \
          -v "$PROJECT_ROOT/config":/app/config:ro \
          $IMAGE_NAME "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

CSV="$LOG_DIR/python/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
    if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
        python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
        echo "[INFO] Run config captured -> $ENV_JSON"
    elif docker run --rm \
        -v "$LOG_DIR:/logs" \
        -v "$PROJECT_ROOT/analysis/src:/src:ro" \
        -e PYTHONPATH=/src \
        -e BENCHMARK_TS="${BENCHMARK_TS}" \
        python:3.12-slim \
        python -m benchmark_analysis.environment "/logs/python/${BENCHMARK_TS}.csv" >/dev/null 2>&1; then
        echo "[INFO] Run config captured (via Docker) -> $ENV_JSON"
    else
        echo "[WARN] Could not write configs.json"
    fi
fi
