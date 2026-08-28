#!/usr/bin/env bash
# Verify host toolchains needed by language benchmark runners (does not install).
# Usage:
#   ./scripts/check-host-requirements.sh           # all enabled languages + analysis
#   ./scripts/check-host-requirements.sh csharp python
#   ./scripts/check-host-requirements.sh --all     # every known language id
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
FAIL=0
WARN=0

ok()   { echo -e "  ${GREEN}OK${NC}  $*"; }
miss() { echo -e "  ${RED}MISS${NC} $*"; FAIL=1; }
warn() { echo -e "  ${YELLOW}WARN${NC} $*"; WARN=$((WARN + 1)); }

need_cmd() {
  local name="$1" hint="${2:-}"
  if command -v "$name" >/dev/null 2>&1; then
    local ver
    ver="$("$name" --version 2>/dev/null | head -1 || true)"
    ok "$name${ver:+ ($ver)}"
    return 0
  fi
  miss "$name${hint:+ — $hint}"
  return 1
}

check_analysis() {
  echo "analysis (configs.json / analyze-benchmarks)"
  need_cmd python3 "Python 3.10+ recommended" || true
  need_cmd uv "https://docs.astral.sh/uv/ — also used by python benchmark runner" || true
}

check_csharp() {
  echo "csharp"
  # SDK 9+ required so LightProto's generator (Roslyn 4.14+) runs; net8 TFM still needs 8.x runtime/packs.
  if command -v dotnet >/dev/null 2>&1; then
    local sdks
    sdks="$(dotnet --list-sdks 2>/dev/null | tr '\n' ' ')"
    if echo "$sdks" | grep -qE '(^|[[:space:]])9\.'; then
      ok "dotnet SDK 9.x present ($sdks)"
      if ! echo "$sdks" | grep -qE '(^|[[:space:]])8\.'; then
        warn "dotnet SDK 8.x missing — net8.0 TFM targeting pack may be pulled on first build"
      fi
    elif echo "$sdks" | grep -qE '(^|[[:space:]])8\.'; then
      miss "dotnet SDK 9.x required for LightProto source generator (found only: $sdks)"
    else
      miss "dotnet SDK 9.x (found: $sdks)"
    fi
  else
    miss "dotnet — install .NET SDK 9: ./scripts/install-host-requirements.sh csharp"
  fi
}

check_python() {
  echo "python"
  need_cmd uv "curl -LsSf https://astral.sh/uv/install.sh | sh" || true
  if command -v uv >/dev/null 2>&1; then
    ok "uv can provision Python 3.12+ via uv sync"
  fi
}

check_go() {
  echo "go"
  if command -v go >/dev/null 2>&1; then
    ok "go ($(go version 2>/dev/null)) [GOTOOLCHAIN=${GOTOOLCHAIN:-auto}]"
  else
    miss "go — https://go.dev/dl/ (bootstrap 1.22+; module uses toolchain go1.24.x)"
  fi
}

check_rust() {
  echo "rust"
  need_cmd cargo "https://rustup.rs/" || true
  need_cmd rustc || true
}

check_javascript() {
  echo "javascript"
  need_cmd node "Node.js 18+" || true
  need_cmd npm || true
}


check_php() {
  echo "php"
  local php_bin=""
  if [[ -x "${HOME}/.local/php/bin/php" ]]; then
    php_bin="${HOME}/.local/php/bin/php"
  elif command -v php >/dev/null 2>&1; then
    php_bin="$(command -v php)"
  fi
  if [[ -n "$php_bin" ]]; then
    ver="$("$php_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
    major="$("$php_bin" -r 'echo PHP_MAJOR_VERSION;')"
    minor="$("$php_bin" -r 'echo PHP_MINOR_VERSION;')"
    if [[ "$major" -gt 8 || ( "$major" -eq 8 && "$minor" -ge 2 ) ]]; then
      ok "php $("$php_bin" -v | head -1)"
    else
      miss "php 8.2+ (found: $ver) — ./scripts/install-host-requirements.sh php"
    fi
  else
    miss "php 8.2+ — ./scripts/install-host-requirements.sh php"
  fi
  if [[ -x "${HOME}/.local/bin/composer" ]] || command -v composer >/dev/null 2>&1; then
    ok "composer"
  else
    miss "composer — ./scripts/install-host-requirements.sh php"
  fi
}

check_kotlin() {
  echo "kotlin"
  local java_bin=""
  if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
    java_bin="${HOME}/.local/jdk-21/bin/java"
  elif command -v java >/dev/null 2>&1; then
    java_bin="$(command -v java)"
  fi
  if [[ -n "$java_bin" ]]; then
    ver="$("$java_bin" -version 2>&1 | head -1)"
    major="$("$java_bin" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}' | tr -d ' \r' | cut -d. -f1)"
    if [[ -n "$major" && "$major" -ge 17 ]]; then
      ok "java $ver"
    else
      miss "java 17+ (found: $ver) — ./scripts/install-host-requirements.sh kotlin"
    fi
  else
    miss "java 17+ — ./scripts/install-host-requirements.sh kotlin"
  fi
  if [[ -x "${PROJECT_ROOT}/kotlin/gradlew" ]]; then
    ok "kotlin/gradlew (in-tree Gradle wrapper)"
  else
    miss "kotlin/gradlew — Gradle wrapper missing from the repo"
  fi
}


check_java() {
  echo "java"
  local java_bin=""
  if [[ -x "${HOME}/.local/jdk-21/bin/java" ]]; then
    java_bin="${HOME}/.local/jdk-21/bin/java"
  elif command -v java >/dev/null 2>&1; then
    java_bin="$(command -v java)"
  fi
  if [[ -n "$java_bin" ]]; then
    ver="$("$java_bin" -version 2>&1 | head -1)"
    major="$("$java_bin" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}' | tr -d ' \r' | cut -d. -f1)"
    if [[ -n "$major" && "$major" -ge 17 ]]; then
      ok "java $ver"
    else
      miss "java 17+ (found: $ver) — ./scripts/install-host-requirements.sh java"
    fi
  else
    miss "java 17+ — ./scripts/install-host-requirements.sh java"
  fi
  if command -v mvn >/dev/null 2>&1 || [[ -x "${HOME}/.local/maven/bin/mvn" ]]; then
    ok "mvn"
  else
    miss "mvn (Maven 3.9+) — ./scripts/install-host-requirements.sh java"
  fi
}


check_cpp() {
  echo "cpp"
  need_cmd g++ "or clang++ (C++20)" || true
  if command -v g++ >/dev/null 2>&1; then
    ver="$(g++ -dumpversion 2>/dev/null || true)"
    ok "g++ $ver"
  elif command -v clang++ >/dev/null 2>&1; then
    ok "clang++ $(clang++ --version | head -1)"
  else
    miss "g++ or clang++ with C++20"
  fi
  need_cmd cmake "3.16+ for FetchContent" || true
  need_cmd git "FetchContent clones" || true
  # Optional: libboost_serialization for boost_serialization codec; avro_c needs c/ third_party avro
  if ldconfig -p 2>/dev/null | grep -q libboost_serialization; then ok "libboost_serialization"; else echo "  note: libboost-serialization-dev optional for boost_serialization"; fi
}


check_c() {
  echo "c"
  need_cmd cmake "https://cmake.org/ or package manager" || true
  need_cmd curl "used by c/scripts/fetch-and-build-deps.sh" || true
  if command -v pkg-config >/dev/null 2>&1; then
    ok "pkg-config"
  else
    warn "pkg-config not found (often needed for system libs)"
  fi
}


check_swift() {
  echo "swift"
  if [[ -x "${HOME}/.local/swift/usr/bin/swift" ]]; then
    export PATH="${HOME}/.local/swift/usr/bin:${PATH}"
  fi
  if command -v swift >/dev/null 2>&1; then
    ok "swift ($(swift --version 2>/dev/null | head -1))"
  else
    miss "swift — ./scripts/install-host-requirements.sh swift"
  fi
  local prefix="${HOME}/.local"
  if [[ -f "${prefix}/include/capnp/generated-header-support.h" ]]; then
    ok "capnproto headers (${prefix}/include/capnp)"
  else
    miss "capnproto C++ headers — ./scripts/install-host-requirements.sh swift (installs Cap'n Proto ${prefix})"
  fi
  if [[ -f "${prefix}/lib/libcapnp.so" ]] || [[ -f "${prefix}/lib/libcapnp.a" ]] \
    || [[ -f "${prefix}/lib64/libcapnp.so" ]] || [[ -f "${prefix}/lib64/libcapnp.a" ]]; then
    ok "libcapnp under ${prefix}/lib"
  else
    miss "libcapnp — ./scripts/install-host-requirements.sh swift"
  fi
}

check_zig() {
  echo "zig"
  if [[ -x "${HOME}/.local/zig/zig" ]]; then
    export PATH="${HOME}/.local/zig:${PATH}"
  elif [[ -x "${HOME}/.local/zig-x86_64-linux-0.16.0/zig" ]]; then
    export PATH="${HOME}/.local/zig-x86_64-linux-0.16.0:${PATH}"
  fi
  if command -v zig >/dev/null 2>&1; then
    ver="$(zig version 2>/dev/null || true)"
    case "$ver" in
      0.16.*) ok "zig $ver" ;;
      *) miss "zig 0.16.x (found: ${ver:-unknown}) — ./scripts/install-host-requirements.sh zig" ;;
    esac
  else
    miss "zig 0.16.x — ./scripts/install-host-requirements.sh zig"
  fi
}

KNOWN=(analysis csharp python go rust javascript c java kotlin php cpp swift zig)

resolve_targets() {
  local args=("$@")
  if [[ ${#args[@]} -eq 0 ]]; then
    # enabled languages from config + analysis
    local enabled
    enabled="$(bench_read_config --enabled-langs 2>/dev/null || true)"
    TARGETS=(analysis)
    if [[ -n "$enabled" ]]; then
      # shellcheck disable=SC2206
      TARGETS+=( $enabled )
    else
      TARGETS+=(csharp python go rust javascript c java kotlin php cpp swift zig)
    fi
    return
  fi
  if [[ "${args[0]}" == "--all" ]]; then
    TARGETS=("${KNOWN[@]}")
    return
  fi
  TARGETS=("${args[@]}")
}

resolve_targets "$@"
echo "Host requirement check (PATH includes user-local toolchains)"
echo "Repo: $PROJECT_ROOT"
echo

for t in "${TARGETS[@]}"; do
  case "$t" in
    analysis|analyze) check_analysis ;;
    csharp|cs|c-sharp|dotnet) check_csharp ;;
    python|py) check_python ;;
    go|golang) check_go ;;
    rust|rs) check_rust ;;
    javascript|js|node) check_javascript ;;
    c|native) check_c ;;
    java|jdk|jvm) check_java ;;
    kotlin|kt) check_kotlin ;;
    php) check_php ;;
    cpp|c++|cxx|cplusplus) check_cpp ;;
    swift) check_swift ;;
    zig) check_zig ;;
    *) echo -e "${YELLOW}Unknown target: $t${NC}"; FAIL=1 ;;
  esac
  echo
done

if [[ "$FAIL" -ne 0 ]]; then
  echo -e "${RED}Some required tools are missing.${NC}"
  echo "Install user-local toolchains with:"
  echo "  ./scripts/install-host-requirements.sh ${*:-}"
  exit 1
fi
if [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}Check finished with $WARN warning(s).${NC}"
else
  echo -e "${GREEN}All checked tools are available.${NC}"
fi
