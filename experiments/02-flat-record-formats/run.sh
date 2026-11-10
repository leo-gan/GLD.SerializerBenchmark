#!/usr/bin/env bash
# Experiment 2 — run one language or every language.
set -euo pipefail

EXPERIMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export EXPERIMENT_DIR
export SAVE_SAMPLE_WHEN="python"
exec bash "$EXPERIMENT_DIR/../lib/run_experiment.sh" "$@"
