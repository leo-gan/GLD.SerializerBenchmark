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

# Absolute path to library run-config YAML for a benchmark-runner mode (from master config).
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

# Language id from a run-benchmarks.sh path. c-sharp before c.
# The caller path is often relative (./scripts/run-benchmarks.sh). Resolve it
# before matching, or Go and C# never receive the data-set filter.
_bench_lang_id() {
  local src="$1" dir base
  dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd)" || dir="$(dirname "$src")"
  base="$(basename "$src")"
  src="${dir}/${base}"
  case "$src" in
    */c-sharp/*|*/csharp/*) echo csharp ;;
    */cpp/*) echo cpp ;;
    */python/*) echo python ;;
    */rust/*) echo rust ;;
    */javascript/*) echo javascript ;;
    */go/*) echo go ;;
    */java/*) echo java ;;
    */kotlin/*) echo kotlin ;;
    */php/*) echo php ;;
    */swift/*) echo swift ;;
    */zig/*) echo zig ;;
    */mojo/*) echo mojo ;;
    */fortran/*) echo fortran ;;
    */c/*) echo c ;;
    *) echo "" ;;
  esac
}

# Fill an empty FILTER_SER from serializer_data_sets on specialized run configs.
# Suite prints SKIP and is left alone. Runners that are not exact-comma also
# print SKIP (Python applies the map itself; substring runners must not
# receive a comma list).
_bench_apply_dataset_filter() {
  local src="$1"
  local lang line py
  lang="$(_bench_lang_id "$src")"
  if [[ -z "$lang" || -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
    return 0
  fi
  if [[ -n "${FILTER_SER:-}" ]]; then
    return 0
  fi
  py="$(bench_config_py)"
  if ! line="$(PYTHONPATH="${_BENCH_REPO_ROOT}/analysis/src${PYTHONPATH:+:$PYTHONPATH}" \
      "$py" "${_BENCH_REPO_ROOT}/scripts/serializer_data_sets.py" \
      --lang "$lang" --run-config "$BENCHMARK_RUN_CONFIG")"; then
    echo "[ERROR] serializer_data_sets lookup failed for $lang" >&2
    return 1
  fi
  if [[ "$line" == "SKIP" || -z "$line" ]]; then
    return 0
  fi
  FILTER_SER="$line"
  echo "[INFO] serializer data set filter ($lang): $FILTER_SER"
}

# Export BENCHMARK_RUN_CONFIG from master config unless already set (caller override).
# Usage in run-benchmarks.sh after MODE is known:
#   bench_export_run_config "$MODE"
# Also fills an empty FILTER_SER for specialized sets on exact-comma runners.
bench_export_run_config() {
  local mode="${1:-all-single}"
  if [[ -z "${BENCHMARK_RUN_CONFIG:-}" ]]; then
    export BENCHMARK_RUN_CONFIG
    BENCHMARK_RUN_CONFIG="$(bench_run_config_for_mode "$mode")"
  fi
  _bench_apply_dataset_filter "${BASH_SOURCE[1]:-}"
}
