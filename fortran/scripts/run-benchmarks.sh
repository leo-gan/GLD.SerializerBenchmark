#!/usr/bin/env bash
# Fortran benchmark runner. Bytes only. Smoke times json-fortran.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORTRAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$FORTRAN_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/fortran}"
mkdir -p "$LOG_DIR" "$FORTRAN_DIR/build"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research] [serializerFilter] [dataFilter]"
    exit 1
    ;;
esac

REPS="$(bench_mode_reps "$MODE")"
if [[ "$MODE" == "smoke" ]]; then
  FILTER_SER="${FILTER_SER:-json-fortran}"
  # Suite smoke stays on message. A caller that sets BENCHMARK_RUN_CONFIG
  # (array-smoke, for example) keeps every type in that file unless they
  # pass a data filter as the third argument.
  if [[ -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_REPO_ROOT="${BENCHMARK_REPO_ROOT:-$PROJECT_ROOT}"
bench_export_run_config "$MODE"

echo "[INFO] Building Fortran benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
export PATH="${HOME}/.local/bin:${PATH}"
# shellcheck source=fpm-env.sh
source "$SCRIPT_DIR/fpm-env.sh"
(
  cd "$FORTRAN_DIR"
  fpm build --profile release
)

CELLS="$(mktemp)"
trap 'rm -f "$CELLS"' EXIT
PYTHONPATH="${PROJECT_ROOT}/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
  python3 "$PROJECT_ROOT/scripts/resolve_run_config.py" "$BENCHMARK_RUN_CONFIG" --seed "$BENCHMARK_SEED" \
  | python3 -c '
import json, sys
d = json.load(sys.stdin)
for c in d["cells"]:
    tc = c.get("type_config") or {}
    print(
        c["type_id"],
        c["data_type_instance_count"],
        c.get("type_config_hash", ""),
        int(tc.get("points", 32)),
        int(tc.get("children", 8)),
        int(tc.get("count", 32)),
        int(tc.get("attr_count", 4)),
        int(tc.get("tag_count", 2)),
        int(tc.get("ny", 0)),
        int(tc.get("nx", 0)),
        int((tc.get("window") or {}).get("x0", 0)),
        int((tc.get("window") or {}).get("y0", 0)),
        int((tc.get("window") or {}).get("wx", 0)),
        int((tc.get("window") or {}).get("wy", 0)),
        sep="\t",
    )
' > "$CELLS"

echo "[INFO] Running serializer_benchmark_fortran"
(
  cd "$FORTRAN_DIR"
  fpm run --profile release serializer_benchmark_fortran -- \
    "$REPS" "$CELLS" "$LOG_DIR" "$BENCHMARK_TS" "$FILTER_SER" "$FILTER_DATA"
)

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> ${CSV%.csv}.configs.json"
  else
    echo "[WARN] Could not write configs.json"
  fi
fi
echo "[SUCCESS] Fortran logs in $LOG_DIR"
