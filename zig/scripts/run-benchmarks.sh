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

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/zig}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event (smoke default: message)"
    exit 1
    ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-std.json}"
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_LANGUAGE=zig

bench_export_run_config "$MODE"

if ! command -v zig >/dev/null 2>&1; then
  echo "[ERROR] zig not found. Run: ./scripts/install-host-requirements.sh zig" >&2
  exit 1
fi

echo "[INFO] Building Zig benchmark (release, mode=$MODE reps=$REPS seed=$BENCHMARK_SEED) $(zig version)..."
cd "$ZIG_DIR"
zig build -Doptimize=ReleaseFast
# Cap’n Proto C ABI is a system-linked .so (not Zig LLD + libkj.a).
export LD_LIBRARY_PATH="${ZIG_DIR}/zig-out/lib:${HOME}/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

ARGS=("$REPS")
if [[ "$MODE" != "custom" ]]; then
  [[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
  [[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
else
  ARGS=("$REPS")
  [[ -n "${3:-}" ]] && ARGS+=("$3")
  [[ -n "${4:-}" ]] && ARGS+=("$4")
fi

export LOG_DIR
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
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] Zig logs in $LOG_DIR"
