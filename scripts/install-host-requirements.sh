#!/usr/bin/env bash
# Install *user-local* host toolchains for language harnesses (no sudo).
# Project deps (uv sync, npm install, cargo fetch, C third_party) stay in
# each language's run-benchmarks.sh — this script only prepares compilers/runtimes.
#
# Usage:
#   ./scripts/install-host-requirements.sh              # enabled langs + analysis tools
#   ./scripts/install-host-requirements.sh csharp go
#   ./scripts/install-host-requirements.sh --all
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

echo "[INFO] Install target: user-local under \$HOME (no system packages / no Docker)"
echo

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    echo "[OK] uv already present: $(command -v uv)"
    return
  fi
  echo "[INFO] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  bench_extend_host_path
}

install_dotnet() {
  bench_extend_host_path
  if command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks 2>/dev/null | grep -qE '^8\.'; then
    echo "[OK] .NET SDK 8 already present ($(dotnet --version))"
    return
  fi
  echo "[INFO] Installing .NET SDK 8.0 to ~/.dotnet ..."
  curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  bash /tmp/dotnet-install.sh --channel 8.0 --install-dir "${HOME}/.dotnet"
  export DOTNET_ROOT="${HOME}/.dotnet"
  export PATH="${HOME}/.dotnet:${PATH}"
  echo "[OK] dotnet $(dotnet --version)"
}

install_go() {
  bench_extend_host_path
  # Bootstrap go is enough if GOTOOLCHAIN=auto can fetch the module toolchain.
  if command -v go >/dev/null 2>&1; then
    echo "[OK] go bootstrap present: $(go version)"
    echo "     (module may download a newer toolchain via GOTOOLCHAIN=auto)"
    return
  fi
  local go_ver=1.24.5
  local arch go_arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) go_arch=amd64 ;;
    aarch64|arm64) go_arch=arm64 ;;
    *) echo "[ERROR] Unsupported arch: $arch" >&2; exit 1 ;;
  esac
  echo "[INFO] Installing Go ${go_ver} to ~/.local/go ..."
  curl -sSL "https://go.dev/dl/go${go_ver}.linux-${go_arch}.tar.gz" -o /tmp/go-sdk.tgz
  rm -rf "${HOME}/.local/go"
  mkdir -p "${HOME}/.local"
  tar -C "${HOME}/.local" -xzf /tmp/go-sdk.tgz
  export PATH="${HOME}/.local/go/bin:${PATH}"
  echo "[OK] $(go version)"
}

install_rust() {
  bench_extend_host_path
  if command -v cargo >/dev/null 2>&1; then
    echo "[OK] cargo already present: $(cargo --version)"
    return
  fi
  echo "[INFO] Installing rustup (default toolchain)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
  echo "[OK] $(cargo --version)"
}

install_node_hint() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "[OK] node $(node --version), npm $(npm --version)"
    return
  fi
  echo "[WARN] Node.js/npm not found. Install via nvm, fnm, or your package manager:"
  echo "       https://nodejs.org/ (this script does not install system Node without sudo)"
}


install_java() {
  bench_extend_host_path
  local jdk="${HOME}/.local/jdk-21"
  local mvn_home="${HOME}/.local/maven"
  if [[ -x "$jdk/bin/java" ]]; then
    echo "[OK] JDK present: $($jdk/bin/java -version 2>&1 | head -1)"
  else
    echo "[INFO] Installing Temurin 21 to $jdk ..."
    local arch jarch
    arch="$(uname -m)"
    case "$arch" in
      x86_64) jarch=x64 ;;
      aarch64|arm64) jarch=aarch64 ;;
      *) echo "[ERROR] Unsupported arch: $arch" >&2; exit 1 ;;
    esac
    local url="https://api.adoptium.net/v3/binary/latest/21/ga/linux/${jarch}/jdk/hotspot/normal/eclipse?project=jdk"
    curl -fsSL -o /tmp/jdk21.tar.gz "$url"
    rm -rf "$jdk" /tmp/jdk21-extract
    mkdir -p /tmp/jdk21-extract
    tar -C /tmp/jdk21-extract -xzf /tmp/jdk21.tar.gz
    local top
    top="$(ls /tmp/jdk21-extract)"
    mv "/tmp/jdk21-extract/$top" "$jdk"
    echo "[OK] $($jdk/bin/java -version 2>&1 | head -1)"
  fi
  export JAVA_HOME="$jdk"
  export PATH="$jdk/bin:$PATH"
  if [[ -x "$mvn_home/bin/mvn" ]]; then
    echo "[OK] Maven present: $($mvn_home/bin/mvn -version | head -1)"
  else
    echo "[INFO] Installing Maven 3.9.9 to $mvn_home ..."
    curl -fsSL -o /tmp/maven.tgz       "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz"
    rm -rf "$mvn_home" /tmp/maven-extract
    mkdir -p /tmp/maven-extract
    tar -C /tmp/maven-extract -xzf /tmp/maven.tgz
    local top
    top="$(ls /tmp/maven-extract)"
    mv "/tmp/maven-extract/$top" "$mvn_home"
    echo "[OK] $($mvn_home/bin/mvn -version | head -1)"
  fi
  export PATH="$mvn_home/bin:$PATH"
}

install_c_hint() {
  if command -v cmake >/dev/null 2>&1; then
    echo "[OK] cmake $(cmake --version | head -1)"
  else
    echo "[WARN] cmake not found — install via package manager or https://cmake.org/"
  fi
  if command -v curl >/dev/null 2>&1; then
    echo "[OK] curl"
  else
    echo "[WARN] curl not found"
  fi
  echo "[NOTE] C third-party libs are built by c/scripts/fetch-and-build-deps.sh on first run."
}

KNOWN=(analysis csharp python go rust javascript c java)

resolve_targets() {
  local args=("$@")
  if [[ ${#args[@]} -eq 0 ]]; then
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
echo "Installing host requirements for: ${TARGETS[*]}"
echo

for t in "${TARGETS[@]}"; do
  case "$t" in
    analysis|analyze)
      install_uv
      ;;
    csharp|cs|c-sharp|dotnet)
      install_dotnet
      ;;
    python|py)
      install_uv
      ;;
    go|golang)
      install_go
      ;;
    rust|rs)
      install_rust
      ;;
    javascript|js|node)
      install_node_hint
      ;;
    c|native)
      install_c_hint
      ;;
    java|jdk)
      install_java
      ;;
    *)
      echo "[ERROR] Unknown target: $t" >&2
      exit 1
      ;;
  esac
  echo
done

echo "[INFO] Re-checking..."
"$PROJECT_ROOT/scripts/check-host-requirements.sh" "${@:-}" || true

echo
echo "Done. Ensure your shell PATH includes user-local bins, e.g.:"
echo "  export PATH=\"\$HOME/.dotnet:\$HOME/.local/go/bin:\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\""
echo "  export DOTNET_ROOT=\"\$HOME/.dotnet\""
echo "Runners source scripts/lib/config.sh which extends PATH automatically."
