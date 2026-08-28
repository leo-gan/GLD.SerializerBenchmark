#!/usr/bin/env bash
# Install *user-local* host toolchains for language benchmark runners (no sudo).
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
  # SDK 9+ required for LightProto source generator (Roslyn 4.14+). Project still targets net8.0.
  # Keep net8 runtime/targeting pack available for the TFM when possible.
  bench_extend_host_path
  local need_sdk9=1 need_sdk8=1
  if command -v dotnet >/dev/null 2>&1; then
    if dotnet --list-sdks 2>/dev/null | grep -qE '^9\.'; then need_sdk9=0; fi
    if dotnet --list-sdks 2>/dev/null | grep -qE '^8\.'; then need_sdk8=0; fi
  fi
  if [[ "$need_sdk9" -eq 0 && "$need_sdk8" -eq 0 ]]; then
    echo "[OK] .NET SDK 8+9 present ($(dotnet --list-sdks 2>/dev/null | tr '\n' ' '))"
    return
  fi
  curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  if [[ "$need_sdk8" -eq 1 ]]; then
    echo "[INFO] Installing .NET SDK 8.0 to ~/.dotnet (net8.0 TFM)..."
    bash /tmp/dotnet-install.sh --channel 8.0 --install-dir "${HOME}/.dotnet"
  fi
  if [[ "$need_sdk9" -eq 1 ]]; then
    echo "[INFO] Installing .NET SDK 9.0 to ~/.dotnet (LightProto source generator)..."
    bash /tmp/dotnet-install.sh --channel 9.0 --install-dir "${HOME}/.dotnet"
  fi
  export DOTNET_ROOT="${HOME}/.dotnet"
  export PATH="${HOME}/.dotnet:${PATH}"
  echo "[OK] dotnet SDKs: $(dotnet --list-sdks 2>/dev/null | tr '\n' ' ')"
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



install_cpp() {
  echo "cpp"
  if command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1; then
    echo "[OK] C++ compiler present"
  else
    echo "[NOTE] Install g++ (build-essential) or clang++ via your package manager (may need sudo)."
  fi
  if command -v cmake >/dev/null 2>&1; then
    echo "[OK] cmake $(cmake --version | head -1)"
  else
    echo "[NOTE] Install cmake >= 3.16 (or use ~/.local/bin/cmake)."
  fi
  echo "[NOTE] C++ third-party libs are fetched by CMake FetchContent on first build (cpp/third_party/)."
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


# Cap'n Proto C++ runtime for Swift CapnpBridge (headers require CAPNP_VERSION 1000002).
install_capnp() {
  local prefix="${HOME}/.local"
  if [[ -f "${prefix}/include/capnp/generated-header-support.h" ]] \
    && { [[ -f "${prefix}/lib/libcapnp.so" ]] || [[ -f "${prefix}/lib/libcapnp.a" ]] \
      || [[ -f "${prefix}/lib64/libcapnp.so" ]] || [[ -f "${prefix}/lib64/libcapnp.a" ]]; }; then
    echo "[OK] capnproto present under ${prefix}"
    export PATH="${prefix}/bin:${PATH}"
    export LD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    return
  fi
  if ! command -v cmake >/dev/null 2>&1; then
    echo "[ERROR] cmake required to build capnproto for Swift CapnpBridge" >&2
    exit 1
  fi
  local ver=1.0.2
  local url="https://github.com/capnproto/capnproto/archive/refs/tags/v${ver}.tar.gz"
  echo "[INFO] Building Cap'n Proto ${ver} into ${prefix} (needed by Swift CapnpBridge) ..."
  local work="/tmp/capnp-install-$$"
  rm -rf "$work"
  mkdir -p "$work" "$prefix"
  curl -fsSL "$url" -o "$work/capnp.tgz"
  tar -xzf "$work/capnp.tgz" -C "$work"
  local src
  src="$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -1)"
  cmake -S "$src/c++" -B "$work/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DBUILD_TESTING=OFF
  cmake --build "$work/build" -j"$(nproc 2>/dev/null || echo 2)"
  cmake --install "$work/build"
  rm -rf "$work"
  export PATH="${prefix}/bin:${PATH}"
  export LD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  echo "[OK] capnproto installed: $(capnp --version 2>/dev/null || echo v${ver})"
}

install_swift() {
  bench_extend_host_path
  if [[ -x "${HOME}/.local/swift/usr/bin/swift" ]]; then
    export PATH="${HOME}/.local/swift/usr/bin:${PATH}"
  fi
  if ! command -v swift >/dev/null 2>&1; then
    local ver=6.3.3
    local arch
    arch="$(uname -m)"
    case "$arch" in
      x86_64) ;;
      aarch64|arm64) ;;
      *) echo "[ERROR] Unsupported arch for Swift tarball: $arch" >&2; exit 1 ;;
    esac
    # Map host OS to official Swift Linux tarball id (fallback ubuntu22.04).
    local os_tag=ubuntu2204
    local dir_suffix=ubuntu22.04
    if [[ -f /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      local id="${ID:-}"
      local ver_id="${VERSION_ID:-}"
      if [[ "$id" == "ubuntu" ]]; then
        case "$ver_id" in
          24.04) os_tag=ubuntu2404; dir_suffix=ubuntu24.04 ;;
          22.04) os_tag=ubuntu2204; dir_suffix=ubuntu22.04 ;;
          20.04) os_tag=ubuntu2004; dir_suffix=ubuntu20.04 ;;
          *)
            echo "[WARN] Ubuntu ${ver_id} not in Swift matrix; trying ubuntu22.04 tarball"
            ;;
        esac
      elif [[ "$id" == "debian" ]]; then
        # Closest supported Swift Linux build.
        os_tag=ubuntu2204
        dir_suffix=ubuntu22.04
      else
        echo "[WARN] Non-Ubuntu Linux (${id:-unknown}); trying ubuntu22.04 Swift tarball"
      fi
    fi
    local dir="swift-${ver}-RELEASE-${dir_suffix}"
    local url="https://download.swift.org/swift-${ver}-release/${os_tag}/swift-${ver}-RELEASE/${dir}.tar.gz"
    echo "[INFO] Installing Swift ${ver} (${dir_suffix}) to ~/.local/swift ..."
    mkdir -p /tmp/swift-install "${HOME}/.local"
    if ! curl -fL "$url" -o /tmp/swift-install/swift.tar.gz; then
      echo "[WARN] Download failed for ${os_tag}; retrying ubuntu2204"
      dir="swift-${ver}-RELEASE-ubuntu22.04"
      url="https://download.swift.org/swift-${ver}-release/ubuntu2204/swift-${ver}-RELEASE/${dir}.tar.gz"
      curl -fL "$url" -o /tmp/swift-install/swift.tar.gz
    fi
    rm -rf "${HOME}/.local/swift" /tmp/swift-install/extracted
    mkdir -p /tmp/swift-install/extracted
    tar -xzf /tmp/swift-install/swift.tar.gz -C /tmp/swift-install/extracted
    local top
    top="$(find /tmp/swift-install/extracted -mindepth 1 -maxdepth 1 -type d | head -1)"
    mv "$top" "${HOME}/.local/swift"
    rm -f /tmp/swift-install/swift.tar.gz
    export PATH="${HOME}/.local/swift/usr/bin:${PATH}"
    echo "[OK] $(swift --version | head -1)"
  else
    echo "[OK] swift already present: $(swift --version 2>/dev/null | head -1)"
  fi
  # CapnpBridge links against system/user libcapnp (same version as generated headers: 1.0.2).
  install_capnp
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

KNOWN=(analysis csharp python go rust javascript c java kotlin cpp swift)

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
      TARGETS+=(csharp python go rust javascript c java kotlin cpp swift)
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
    java|jdk|jvm)
      install_java
      ;;
    kotlin|kt)
      install_java
      ;;
    cpp|c++|cxx|cplusplus)
      install_cpp
      ;;
    swift)
      install_swift
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
