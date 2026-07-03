# shellcheck shell=bash
# Shared helpers to read config/benchmark_config.yaml.
# Source from repo scripts:
#   SCRIPT_DIR=...; source "$SCRIPT_DIR/../lib/config.sh"   # from scripts/foo/
#   source "$PROJECT_ROOT/scripts/lib/config.sh"

_BENCH_CONFIG_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BENCH_REPO_ROOT="$(cd "$_BENCH_CONFIG_SH_DIR/../.." && pwd)"
_BENCH_READ_CONFIG="${_BENCH_REPO_ROOT}/scripts/read-config.py"
_BENCH_CONFIG_FILE="${BENCH_CONFIG:-${_BENCH_REPO_ROOT}/config/benchmark_config.yaml}"

bench_config_py() {
  # Prefer analysis venv python if present, else python3
  if [[ -x "${_BENCH_REPO_ROOT}/analysis/.venv/bin/python" ]]; then
    echo "${_BENCH_REPO_ROOT}/analysis/.venv/bin/python"
  elif [[ -x "${_BENCH_REPO_ROOT}/python/.venv/bin/python" ]]; then
    echo "${_BENCH_REPO_ROOT}/python/.venv/bin/python"
  else
    echo "python3"
  fi
}

bench_read_config() {
  local py
  py="$(bench_config_py)"
  PYTHONPATH="${_BENCH_REPO_ROOT}/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
    "$py" "$_BENCH_READ_CONFIG" --config "$_BENCH_CONFIG_FILE" "$@"
}

# Echo repetitions for mode (smoke|all-single|full|research). Fallback on failure.
bench_mode_reps() {
  local mode="$1"
  local reps
  reps="$(bench_read_config --mode-reps "$mode" 2>/dev/null)" || true
  if [[ -z "$reps" || ! "$reps" =~ ^[0-9]+$ ]]; then
    case "$mode" in
      smoke) echo 2 ;;
      all-single) echo 10 ;;
      full) echo 100 ;;
      research) echo 500 ;;
      *) echo 10 ;;
    esac
    return
  fi
  echo "$reps"
}

bench_random_seed() {
  local s
  s="$(bench_read_config --seed 2>/dev/null)" || true
  if [[ -z "$s" || ! "$s" =~ ^[0-9]+$ ]]; then
    echo 42
    return
  fi
  echo "$s"
}

bench_logs_root() {
  local d
  d="$(bench_read_config --logs-root 2>/dev/null)" || true
  if [[ -z "$d" ]]; then
    echo "${_BENCH_REPO_ROOT}/logs"
    return
  fi
  echo "$d"
}
