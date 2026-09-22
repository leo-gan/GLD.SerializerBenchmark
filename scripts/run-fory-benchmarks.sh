#!/usr/bin/env bash
# Run only Fory across the integrated runtimes, using each language's normal runner.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/config.sh"
MODE="${1:-all-single}"
LANG_FILTER="${2:-}"
LOG_ROOT="${LOG_DIR:-$PROJECT_ROOT/logs}"
export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
matched=false
for lang in java kotlin python go rust cpp javascript csharp swift; do
  [[ -z "$LANG_FILTER" || "$LANG_FILTER" == "$lang" ]] || continue
  matched=true
  dir="$lang"
  [[ "$lang" != csharp ]] || dir=c-sharp
  echo "[INFO] Fory: $lang ($MODE)"
  LOG_DIR="$LOG_ROOT/$lang" bash "$PROJECT_ROOT/$dir/scripts/run-benchmarks.sh" "$MODE" fory
  # Some existing runners report codec failures in CSV and still exit zero.
  "$(bench_config_py)" - "$LOG_ROOT/$lang/$BENCHMARK_TS.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="") as source:
    rows = list(csv.DictReader(source))
if not rows or any(row["SerializerName"].lower() != "fory" for row in rows):
    raise SystemExit(f"Missing Fory benchmark results: {path}")
for row in rows:
    if row.get("FidelityScore") and float(row["FidelityScore"]) != 1:
        raise SystemExit(f"Fory fidelity failure: {path}")
errors = path.with_suffix(".errors.csv")
if errors.exists():
    with errors.open(newline="") as source:
        if any(csv.DictReader(source)):
            raise SystemExit(f"Fory benchmark errors: {errors}")
print(f"[SUCCESS] Validated {len(rows)} Fory result rows: {path}")
PY
done
if [[ "$matched" == false ]]; then
  echo "Unknown Fory language: $LANG_FILTER" >&2
  exit 1
fi
