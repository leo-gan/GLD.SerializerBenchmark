#!/usr/bin/env bash
# Experiment 15. Times the C runner and a Fortran executable that calls the
# same C adapters. Fortran names are not in benchmark_config.yaml.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
export PATH="${HOME}/.local/go/bin:${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

# shellcheck source=../../scripts/lib/config.sh
source "$REPO/scripts/lib/config.sh"

(
  cd "$REPO/analysis"
  uv run python "$REPO/experiments/lib/experiment_config.py" write-run "$HERE/experiment.yaml"
)

LIBS=(yyjson cJSON mpack tinycbor nanopb avro-c libyaml libbson flatcc ion-c)

if [[ $# -eq 0 ]]; then
  LANGS=(c fortran)
else
  LANGS=("$@")
fi

export BENCHMARK_RUN_CONFIG="$HERE/run.yaml"
export BENCHMARK_REPO_ROOT="$REPO"
export BENCHMARK_SEED="${BENCHMARK_SEED:-42}"

run_c() {
  local dest="$HERE/c/logs/c"
  local combined="$dest/ffi.csv"
  mkdir -p "$dest"
  local name part
  : > "$combined"
  local first=1
  for name in "${LIBS[@]}"; do
    local one="$dest/one-$name"
    mkdir -p "$one"
    echo "[exp-15] c $name"
    if ! LOG_DIR="$one" BENCHMARK_RUN_CONFIG="$HERE/run.yaml" BENCHMARK_REPO_ROOT="$REPO" \
        BENCHMARK_SEED="$BENCHMARK_SEED" bash "$REPO/c/scripts/run-benchmarks.sh" full "$name" document; then
      echo "[exp-15] c $name failed" >&2
      return 1
    fi
    part="$(ls -1t "$one"/*.csv 2>/dev/null | head -n1 || true)"
    if [[ -z "$part" ]]; then
      echo "[exp-15] c $name: no CSV" >&2
      return 1
    fi
    if [[ "$first" -eq 1 ]]; then
      cat "$part" >> "$combined"
      first=0
    else
      tail -n +2 "$part" >> "$combined"
    fi
  done
  (
    cd "$REPO/analysis"
    uv run python "$HERE/summarize.py" --language c --csv "$combined"
  )
}

run_fortran() {
  local dest="$HERE/fortran/logs/fortran"
  mkdir -p "$dest"
  local exe="$REPO/fortran/ffi/ffi_bench"
  bash "$REPO/fortran/ffi/build.sh" "$exe"
  local cells ts reps
  cells="$(mktemp)"
  ts="ffi-$(date +%Y-%m-%d-%H%M%S)"
  reps="$(bench_mode_reps full)"
  PYTHONPATH="${REPO}/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$REPO/scripts/resolve_run_config.py" "$HERE/run.yaml" --seed "$BENCHMARK_SEED" \
    | python3 -c '
import json, sys
d = json.load(sys.stdin)
for c in d["cells"]:
    tc = c.get("type_config") or {}
    print(c["type_id"], c["data_type_instance_count"], c.get("type_config_hash", ""),
          int(tc.get("points", 32)), int(tc.get("children", 8)), int(tc.get("count", 32)),
          int(tc.get("attr_count", 4)), int(tc.get("tag_count", 2)), sep="\t")
' > "$cells"
  BENCHMARK_SEED="$BENCHMARK_SEED" "$exe" "$reps" "$cells" "$dest" "$ts"
  rm -f "$cells"
  local csv="$dest/${ts}.csv"
  (
    cd "$REPO/analysis"
    uv run python "$HERE/summarize.py" --language fortran --csv "$csv"
  )
}

failed=()
for lang in "${LANGS[@]}"; do
  case "$lang" in
    c) run_c || failed+=("$lang") ;;
    fortran) run_fortran || failed+=("$lang") ;;
    *) echo "[exp-15] unknown language: $lang" >&2; failed+=("$lang") ;;
  esac
done

if [[ $# -eq 0 ]]; then
  (
    cd "$REPO/analysis"
    uv run python "$HERE/summarize.py" --all
  )
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "[exp-15] failed: ${failed[*]}" >&2
  exit 1
fi
echo "[exp-15] finished"
