#!/usr/bin/env bash
# Fortran benchmark runner. Bytes only. Smoke times json-fortran.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORTRAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$FORTRAN_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

bench_init_runner fortran json-fortran "$@"
mkdir -p "$FORTRAN_DIR/build"

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

bench_finish_runner Fortran
