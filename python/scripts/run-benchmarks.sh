#!/usr/bin/env bash
set -e

# Configuration — modes match config/benchmark_config.yaml
IMAGE_NAME="python-serializer-benchmark"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

print_usage() {
    echo "Usage: ./scripts/run-benchmarks.sh [smoke | all-single | full | research | custom]"
    echo ""
    echo "Modes (see config/benchmark_config.yaml):"
    echo "  smoke      - 2 repetitions, pickle on Person"
    echo "  all-single - 10 repetitions, all serializers on all test data"
    echo "  full       - 100 repetitions, all serializers"
    echo "  research   - 500 repetitions, all serializers"
    echo "  custom     - Manual: ./scripts/run-benchmarks.sh custom <reps> [serializerFilter] [dataFilter]"
}

echo "[INFO] Ensuring Docker image is up to date..."
docker build -t $IMAGE_NAME -f "$SCRIPT_DIR/../Dockerfile" "$PROJECT_ROOT"

# Ensure timestamp for env sidecar mapping (host captures after Docker exits)
export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"

case "$1" in
    smoke)
        echo "[INFO] Running Smoke Test (2 reps, pickle, Person)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e LOG_DIR="$LOG_DIR" -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas $IMAGE_NAME 2 pickle Person
        ;;
    all-single)
        echo "[INFO] Running All-Single Test (10 reps, All Serializers)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e LOG_DIR="$LOG_DIR" -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas $IMAGE_NAME 10
        ;;
    full)
        echo "[INFO] Running Full Benchmark (100 reps, All Serializers)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e LOG_DIR="$LOG_DIR" -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas $IMAGE_NAME 100
        ;;
    research)
        echo "[INFO] Running Research Benchmark (500 reps, All Serializers)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e LOG_DIR="$LOG_DIR" -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas $IMAGE_NAME 500
        ;;
    custom)
        shift
        echo "[INFO] Running Custom Benchmark (Args: $@)..."
        docker run --rm -e BENCHMARK_TS="${BENCHMARK_TS}" -e LOG_DIR="$LOG_DIR" -v "$LOG_DIR":/app/logs -v "$PROJECT_ROOT/schemas":/app/schemas $IMAGE_NAME "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

# Host-side environment sidecar (analysis package; Docker image may not include it)
CSV="$LOG_DIR/python/${BENCHMARK_TS}.csv"
if [[ -f "$CSV" ]]; then
    if PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" python3 -m benchmark_analysis.environment "$CSV" 2>/dev/null; then
        echo "[INFO] Environment captured -> ${CSV%.csv}.environment.json"
    else
        echo "[WARN] Could not write environment.json (install analysis/ or use run-all-benchmarks.sh)"
    fi
fi
