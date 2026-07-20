# shellcheck shell=bash
# Shared helpers to read config/benchmark_config.yaml.
# Source from repo scripts:
#   SCRIPT_DIR=...; source "$SCRIPT_DIR/../lib/config.sh"   # from scripts/foo/
#   source "$PROJECT_ROOT/scripts/lib/config.sh"

_BENCH_CONFIG_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BENCH_REPO_ROOT="$(cd "$_BENCH_CONFIG_SH_DIR/../.." && pwd)"
_BENCH_READ_CONFIG="${_BENCH_REPO_ROOT}/scripts/read-config.py"
_BENCH_CONFIG_FILE="${BENCH_CONFIG:-${_BENCH_REPO_ROOT}/config/benchmark_config.yaml}"

# User-local toolchains (dotnet-install, go tarball, cargo, uv) often live outside
# a login shell PATH. Extend once when this file is sourced by runners.
bench_extend_host_path() {
  local extras=()
  [[ -d "${HOME}/.dotnet" ]] && extras+=("${HOME}/.dotnet")
  [[ -d "${HOME}/.local/go/bin" ]] && extras+=("${HOME}/.local/go/bin")
  [[ -d "${HOME}/.local/bin" ]] && extras+=("${HOME}/.local/bin")
  [[ -d "${HOME}/.local/jdk-21/bin" ]] && extras+=("${HOME}/.local/jdk-21/bin")
  [[ -d "${HOME}/.local/maven/bin" ]] && extras+=("${HOME}/.local/maven/bin")
  if [[ -d "${HOME}/.local/jdk-21" && -z "${JAVA_HOME:-}" ]]; then
    export JAVA_HOME="${HOME}/.local/jdk-21"
  fi
  [[ -d "${HOME}/.cargo/bin" ]] && extras+=("${HOME}/.cargo/bin")
  [[ -d "${HOME}/.local/swift/usr/bin" ]] && extras+=("${HOME}/.local/swift/usr/bin")
  if ((${#extras[@]})); then
    local joined
    joined="$(IFS=:; echo "${extras[*]}")"
    case ":${PATH:-}:" in
      *":${extras[0]}:"*) ;;
      *) export PATH="${joined}${PATH:+:$PATH}" ;;
    esac
  fi
  if [[ -d "${HOME}/.dotnet" && -z "${DOTNET_ROOT:-}" ]]; then
    export DOTNET_ROOT="${HOME}/.dotnet"
  fi
  # Go module may request a newer toolchain than the host bootstrap (go.mod).
  export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
}
bench_extend_host_path

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

# Absolute path to library run-config YAML for a harness mode (from master config).
# smoke → data_model_v2.smoke_run_config; all other modes → default_run_config.
bench_run_config_for_mode() {
  local mode="${1:-all-single}"
  local path
  path="$(bench_read_config --run-config-for-mode "$mode" 2>/dev/null)" || true
  if [[ -n "$path" && -f "$path" ]]; then
    echo "$path"
    return
  fi
  if [[ "$mode" == "smoke" ]]; then
    echo "${_BENCH_REPO_ROOT}/config/library/smoke.yaml"
  else
    echo "${_BENCH_REPO_ROOT}/config/library/default.yaml"
  fi
}

# Export BENCHMARK_RUN_CONFIG from master config unless already set (caller override).
# Usage in run-benchmarks.sh after MODE is known:
#   bench_export_run_config "$MODE"
bench_export_run_config() {
  local mode="${1:-all-single}"
  if [[ -n "${BENCHMARK_RUN_CONFIG:-}" ]]; then
    return 0
  fi
  export BENCHMARK_RUN_CONFIG
  BENCHMARK_RUN_CONFIG="$(bench_run_config_for_mode "$mode")"
}
