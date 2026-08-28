#!/usr/bin/env bash
# Experiment 4 — run one language or every language.
# Does not refresh the published website tables.
#
#   ./experiments/04-sensor-list-size/run.sh
#   ./experiments/04-sensor-list-size/run.sh rust c
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

# User-local toolchains (same places install-host-requirements.sh uses).
export PATH="${HOME}/.local/go/bin:${HOME}/.cargo/bin:${HOME}/.dotnet:${PATH}"

declare -A RUNNER=(
  [python]="$REPO/python/scripts/run-benchmarks.sh"
  [go]="$REPO/go/scripts/run-benchmarks.sh"
  [java]="$REPO/java/scripts/run-benchmarks.sh"
  [kotlin]="$REPO/kotlin/scripts/run-benchmarks.sh"
  [javascript]="$REPO/javascript/scripts/run-benchmarks.sh"
  [rust]="$REPO/rust/scripts/run-benchmarks.sh"
  [c]="$REPO/c/scripts/run-benchmarks.sh"
  [cpp]="$REPO/cpp/scripts/run-benchmarks.sh"
  [csharp]="$REPO/c-sharp/scripts/run-benchmarks.sh"
  [swift]="$REPO/swift/scripts/run-benchmarks.sh"
)

# experiment.yaml is the file to edit. run.yaml is written from it.
(
  cd "$REPO/analysis"
  uv run python "$REPO/experiments/lib/experiment_config.py" write-run "$HERE/experiment.yaml"
)

mapfile -t CONFIG_LANGS < <(
  cd "$REPO/analysis"
  uv run python "$REPO/experiments/lib/experiment_config.py" languages "$HERE/experiment.yaml"
)

if [[ $# -eq 0 ]]; then
  LANGS=("${CONFIG_LANGS[@]}")
else
  LANGS=("$@")
fi

export BENCHMARK_RUN_CONFIG="$HERE/run.yaml"
export BENCHMARK_REPO_ROOT="$REPO"
export BENCHMARK_SEED="${BENCHMARK_SEED:-42}"

(
  cd "$REPO/analysis"
  uv run python "$HERE/python/save_sample.py"
)

run_one() {
  local lang="$1"
  local script="${RUNNER[$lang]:-}"
  if [[ -z "$script" ]]; then
    echo "[exp-04] unknown language: $lang" >&2
    return 1
  fi
  if [[ ! -f "$script" ]]; then
    echo "[exp-04] missing runner: $script" >&2
    return 1
  fi

  local dest="$HERE/$lang"
  mkdir -p "$dest/logs"
  # Language id as the last folder name so the Python runner does not nest again.
  local log_dir="$dest/logs/$lang"
  mkdir -p "$log_dir"

  echo ""
  echo "[exp-04] ===== $lang ====="
  echo "[exp-04] logs: $log_dir"

  if LOG_DIR="$log_dir" BENCHMARK_RUN_CONFIG="$HERE/run.yaml" \
      BENCHMARK_REPO_ROOT="$REPO" BENCHMARK_SEED="${BENCHMARK_SEED}" \
      bash "$script" full; then
    local csv
    csv="$(ls -1t "$log_dir"/*.csv 2>/dev/null | head -n1 || true)"
    if [[ -z "$csv" ]]; then
      echo "[exp-04] $lang: runner finished but no CSV" >&2
      return 1
    fi
    (
      cd "$REPO/analysis"
      uv run python "$HERE/summarize.py" --language "$lang" --csv "$csv"
    )
  else
    echo "[exp-04] $lang: runner failed" >&2
    return 1
  fi
}

failed=()
for lang in "${LANGS[@]}"; do
  if ! run_one "$lang"; then
    failed+=("$lang")
  fi
done

(
  cd "$REPO/analysis"
  uv run python "$HERE/summarize.py" --all
)

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "[exp-04] failed: ${failed[*]}" >&2
  exit 1
fi
echo "[exp-04] all requested languages finished"
