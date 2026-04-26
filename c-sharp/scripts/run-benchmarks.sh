#!/bin/bash

# Configuration
IMAGE_NAME="serializer-benchmark"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

# Helper function
print_usage() {
    echo "Usage: ./scripts/run-benchmarks.sh [smoke | all-single | full | custom]"
    echo ""
    echo "Modes:"
    echo "  smoke      - 1 repetition of BinarySerializer on Person (Fast verification)"
    echo "  all-single - 1 repetition of all serializers on all test data"
    echo "  full       - 100 repetitions of all serializers (Standard benchmark)"
    echo "  custom     - Manual override: ./scripts/run-benchmarks.sh custom <reps> [serializerFilter] [dataFilter]"
}

# Ensure image is built
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "[INFO] Building Docker image..."
    docker build -t $IMAGE_NAME "$SCRIPT_DIR/.."
fi

case "$1" in
    smoke)
        echo "[INFO] Running Smoke Test (1 rep, Binary, Person)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 1 Binary Person
        ;;
    all-single)
        echo "[INFO] Running All-Single Test (1 rep, All Serializers)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 1
        ;;
    full)
        echo "[INFO] Running Full Benchmark (100 reps, All Serializers)..."
        docker run --rm -v "$LOG_DIR":/app/logs $IMAGE_NAME 100
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

echo "[SUCCESS] Benchmark run complete. Logs available in $LOG_DIR"
