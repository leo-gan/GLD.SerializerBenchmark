#!/bin/bash

# Configuration — modes match config/benchmark_config.yaml
IMAGE_NAME="serializer-benchmark"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

print_usage() {
    echo "Usage: ./scripts/run-benchmarks.sh [smoke | all-single | full | research | custom]"
    echo ""
    echo "Modes (see config/benchmark_config.yaml):"
    echo "  smoke      - 2 repetitions, BinarySerializer on Person"
    echo "  all-single - 10 repetitions, all serializers on all test data"
    echo "  full       - 100 repetitions, all serializers"
    echo "  research   - 500 repetitions, all serializers"
    echo "  custom     - Manual: ./scripts/run-benchmarks.sh custom <reps> [serializerFilter] [dataFilter]"
}

if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "[INFO] Building Docker image..."
    docker build -t $IMAGE_NAME "$SCRIPT_DIR/.."
fi

case "$1" in
    smoke)
        echo "[INFO] Running Smoke Test (2 reps, Binary, Person)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 2 Binary Person
        ;;
    all-single)
        echo "[INFO] Running All-Single Test (10 reps, All Serializers)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 10
        ;;
    full)
        echo "[INFO] Running Full Benchmark (100 reps, All Serializers)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 100
        ;;
    research)
        echo "[INFO] Running Research Benchmark (500 reps, All Serializers)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 500
        ;;
    custom)
        shift
        echo "[INFO] Running Custom Benchmark (Args: $@)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
