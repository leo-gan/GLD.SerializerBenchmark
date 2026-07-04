#!/bin/bash
set -e

# Modes / seed from config/benchmark_config.yaml
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
}

echo "[INFO] Ensuring Docker image is up to date..."
docker build -t $IMAGE_NAME "$SCRIPT_DIR/.."

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"

MODE="${1:-}"
case "$MODE" in
    smoke)
        REPS="$(bench_mode_reps smoke)"
        echo "[INFO] Running Smoke Test ($REPS reps, Binary, Person) [config modes.smoke]..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -v "$LOG_DIR":/app/logs $IMAGE_NAME "$REPS" Binary Person
        ;;
    all-single|full|research)
        REPS="$(bench_mode_reps "$MODE")"
        echo "[INFO] Running $MODE ($REPS reps, all serializers) [config modes.$MODE]..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -v "$LOG_DIR":/app/logs $IMAGE_NAME "$REPS"
        ;;
    custom)
        shift
        echo "[INFO] Running Custom Benchmark (Args: $*)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e BENCHMARK_SEED="${BENCHMARK_SEED}" \
          -v "$LOG_DIR":/app/logs $IMAGE_NAME "$@"
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
