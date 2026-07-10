#!/bin/bash
set -e

# Modes / seed from config/benchmark_config.yaml
# Suite is Data Model v2 only (message/document/telemetry/strings/event).
IMAGE_NAME="serializer-benchmark"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

print_usage() {
    echo "Usage: ./scripts/run-benchmarks.sh [smoke | all-single | full | research | custom]"
    echo ""
    echo "Modes (from config/benchmark_config.yaml):"
    echo "  smoke | all-single | full | research — reps from modes.<name>.repetitions"
    echo "  custom — Manual: ./scripts/run-benchmarks.sh custom <reps> [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message | document | telemetry | strings | event"
}

echo "[INFO] Ensuring Docker image is up to date..."
docker build -t $IMAGE_NAME "$SCRIPT_DIR/.."

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_REPO_ROOT="${BENCHMARK_REPO_ROOT:-$PROJECT_ROOT}"
if [[ -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
  if [[ "${1:-}" == "smoke" ]]; then
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/smoke.yaml"
  else
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/default.yaml"
  fi
fi

# Shared docker env/mounts for all modes
docker_run() {
    # Map host run-config path into the /src mount
    local run_cfg_host="${BENCHMARK_RUN_CONFIG:-$PROJECT_ROOT/config/library/default.yaml}"
    local run_cfg_ctr="/src/config/library/default.yaml"
    if [[ "$run_cfg_host" == "$PROJECT_ROOT"/* ]]; then
        run_cfg_ctr="/src/${run_cfg_host#"$PROJECT_ROOT"/}"
    elif [[ "$run_cfg_host" == /* ]]; then
        # absolute path outside repo: copy not supported; use default
        run_cfg_ctr="/src/config/library/default.yaml"
    else
        run_cfg_ctr="/src/${run_cfg_host}"
    fi
    docker run --rm \
      -e BENCHMARK_TS="${BENCHMARK_TS}" \
      -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
      -e BENCHMARK_REPO_ROOT=/src \
      -e BENCHMARK_RUN_CONFIG="$run_cfg_ctr" \
      -e LOG_DIR=/app/logs \
      -e PYTHONPATH=/src/analysis/src \
      -v "$LOG_DIR":/app/logs \
      -v "$PROJECT_ROOT":/src:ro \
      $IMAGE_NAME "$@"
}

MODE="${1:-}"
case "$MODE" in
    smoke)
        REPS="$(bench_mode_reps smoke)"
        echo "[INFO] Running Smoke Test v2 ($REPS reps) [config modes.smoke]..."
        docker_run "$REPS"
        ;;
    all-single|full|research)
        REPS="$(bench_mode_reps "$MODE")"
        echo "[INFO] Running $MODE v2 ($REPS reps, all serializers) [config modes.$MODE]..."
        docker_run "$REPS"
        ;;
    custom)
        shift
        echo "[INFO] Running Custom Benchmark (Args: $*)..."
        docker_run "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

CSV="$LOG_DIR/csharp/${BENCHMARK_TS}.csv"
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
        python -m benchmark_analysis.environment "/logs/csharp/${BENCHMARK_TS}.csv" >/dev/null 2>&1; then
        echo "[INFO] Run config captured (via Docker) -> $ENV_JSON"
    else
        echo "[WARN] Could not write configs.json"
    fi
fi
