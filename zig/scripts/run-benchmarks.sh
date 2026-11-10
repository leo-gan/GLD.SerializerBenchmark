#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$ZIG_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

if [[ -x "${HOME}/.local/zig/zig" ]]; then
  export PATH="${HOME}/.local/zig:${PATH}"
elif [[ -x "${HOME}/.local/zig-x86_64-linux-0.16.0/zig" ]]; then
  export PATH="${HOME}/.local/zig-x86_64-linux-0.16.0:${PATH}"
fi

bench_init_runner zig "std.json" "$@"

if ! command -v zig >/dev/null 2>&1; then
  echo "[ERROR] zig not found. Run: ./scripts/install-host-requirements.sh zig" >&2
  exit 1
fi

echo "[INFO] Building Zig benchmark (release, mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $(zig version)..."
cd "$ZIG_DIR"
zig build -Doptimize=ReleaseFast
# Cap’n Proto C ABI is a system-linked .so (not Zig LLD + libkj.a).
export LD_LIBRARY_PATH="${ZIG_DIR}/zig-out/lib:${HOME}/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
RESOLVED="$LOG_DIR/${BENCHMARK_TS}.resolved.json"
RUN_CFG="${BENCHMARK_RUN_CONFIG:-$PROJECT_ROOT/config/library/default.yaml}"
if [[ "$MODE" == "smoke" && -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
  RUN_CFG="$PROJECT_ROOT/config/library/smoke.yaml"
fi
PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
  python3 "$PROJECT_ROOT/scripts/resolve_run_config.py" "$RUN_CFG" --seed "$BENCHMARK_SEED" \
  > "$RESOLVED"

STRAT="${BENCHMARK_SCHEDULE:-block_shuffle}"
echo "[INFO] Running: zig-out/bin/serializer-benchmark-zig $REPS $CSV $RESOLVED ${FILTER_SER:-} ${FILTER_DATA:-} $BENCHMARK_SEED $STRAT"
./zig-out/bin/serializer-benchmark-zig \
  "$REPS" \
  "$CSV" \
  "$RESOLVED" \
  "${FILTER_SER:-}" \
  "${FILTER_DATA:-}" \
  "$BENCHMARK_SEED" \
  "$STRAT"

bench_finish_runner Zig
