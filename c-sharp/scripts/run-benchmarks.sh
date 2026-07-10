#!/usr/bin/env bash
# Native .NET 8 runner (same pattern as go/rust/javascript/c — no Docker).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$CS_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs/csharp}"
mkdir -p "$LOG_DIR"

MODE="${1:-all-single}"
FILTER_SER="${2:-}"
FILTER_DATA="${3:-}"

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES custom " in
  *" $MODE "*) ;;
  *)
    echo "Usage: $0 [smoke|all-single|full|research|custom] [serializerFilter] [dataFilter]"
    echo "  dataFilter type_ids: message|document|telemetry|strings|event"
    echo "  Requires: .NET SDK 8.0+ (https://dotnet.microsoft.com/download)"
    exit 1
    ;;
esac

if [[ "$MODE" == "custom" ]]; then
  REPS="${2:-10}"; FILTER_SER="${3:-}"; FILTER_DATA="${4:-}"
else
  REPS="$(bench_mode_reps "$MODE")"
  if [[ "$MODE" == "smoke" ]]; then
    FILTER_SER="${FILTER_SER:-Json.Net}"
    FILTER_DATA="${FILTER_DATA:-message}"
  fi
fi

export BENCHMARK_TS="${BENCHMARK_TS:-$(date +%Y-%m-%d-%H%M%S)}"
export BENCHMARK_SEED="$(bench_random_seed)"
export BENCHMARK_REPO_ROOT="${BENCHMARK_REPO_ROOT:-$PROJECT_ROOT}"
export LOG_DIR

if [[ -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
  if [[ "$MODE" == "smoke" ]]; then
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/smoke.yaml"
  else
    export BENCHMARK_RUN_CONFIG="$PROJECT_ROOT/config/library/default.yaml"
  fi
fi

# Prefer user-local installs (e.g. ~/.dotnet)
export PATH="${HOME}/.dotnet:${HOME}/.local/share/dotnet:${PATH:-}"
if ! command -v dotnet >/dev/null 2>&1; then
  echo "[ERROR] dotnet not found. Install .NET SDK 8.0+: https://dotnet.microsoft.com/download" >&2
  echo "        Or: curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0" >&2
  exit 1
fi

echo "[INFO] Building C# benchmark (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)..."
cd "$CS_DIR"
dotnet build src/GLD.SerializerBenchmark.csproj -c Release --nologo -v q

ARGS=("$REPS")
if [[ "$MODE" != "custom" ]]; then
  [[ -n "$FILTER_SER" ]] && ARGS+=("$FILTER_SER")
  [[ -n "$FILTER_DATA" ]] && ARGS+=("$FILTER_DATA")
else
  ARGS=("$REPS")
  [[ -n "${3:-}" ]] && ARGS+=("$3")
  [[ -n "${4:-}" ]] && ARGS+=("$4")
fi

export PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}"
echo "[INFO] Running: dotnet run --project src -c Release --no-build -- ${ARGS[*]}"
dotnet run --project src/GLD.SerializerBenchmark.csproj -c Release --no-build -- "${ARGS[@]}"

CSV="$LOG_DIR/${BENCHMARK_TS}.csv"
ENV_JSON="${CSV%.csv}.configs.json"
if [[ -f "$CSV" ]]; then
  if BENCHMARK_TS="${BENCHMARK_TS}" PYTHONPATH="$PROJECT_ROOT/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      python3 -m benchmark_analysis.environment "$CSV" >/dev/null 2>&1; then
    echo "[INFO] Run config captured -> $ENV_JSON"
  else
    echo "[WARN] Could not write configs.json (analysis package optional for standalone runs)"
  fi
fi

echo "[SUCCESS] C# logs in $LOG_DIR"
