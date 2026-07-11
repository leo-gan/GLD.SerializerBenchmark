#!/usr/bin/env bash
# Verify host toolchains needed by language harnesses (does not install).
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
  need_cmd uv "https://docs.astral.sh/uv/ — also used by python harness" || true
}

check_csharp() {
  echo "csharp"
  if command -v dotnet >/dev/null 2>&1; then
    if dotnet --list-sdks 2>/dev/null | grep -qE '^8\.'; then
      ok "dotnet SDK 8.x ($(dotnet --version 2>/dev/null))"
    else
      miss "dotnet SDK 8.x (found: $(dotnet --list-sdks 2>/dev/null | tr '\n' ' '))"
    fi
  else
    miss "dotnet — install .NET SDK 8: https://dotnet.microsoft.com/download"
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

KNOWN=(analysis csharp python go rust javascript c java)

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
      TARGETS+=(csharp python go rust javascript c java)
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
    java|jdk) check_java ;;
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
