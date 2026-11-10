#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SWIFT_DIR/.." && pwd)"
# shellcheck source=../../scripts/lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

# Prefer user-local Swift toolchain when present.
if [[ -x "${HOME}/.local/swift/usr/bin/swift" ]]; then
  export PATH="${HOME}/.local/swift/usr/bin:${PATH}"
fi
if [[ -d "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi
if [[ -d "${HOME}/.local/lib" ]]; then
  export LD_LIBRARY_PATH="${HOME}/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBRARY_PATH="${HOME}/.local/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi

bench_init_runner swift JSON "$@"

cd "$SWIFT_DIR"
if ! command -v swift >/dev/null 2>&1; then
  echo "[ERROR] swift not found. Install via ./scripts/install-host-requirements.sh swift" >&2
  exit 1
fi

# Cap'n Proto + local toolchains (Package.swift also reads CAPNP_PREFIX / HOME).
export CAPNP_PREFIX="${CAPNP_PREFIX:-${HOME}/.local}"
export PATH="${CAPNP_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${CAPNP_PREFIX}/lib:${CAPNP_PREFIX}/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# libstdc++ isystem for Swift's clang (toml++ / CapnpBridge). Prefer newest installed.
SWIFT_CXX_INCLUDES=(
  -Xcxx -I -Xcxx "${CAPNP_PREFIX}/include"
  -Xcc -I -Xcc "${CAPNP_PREFIX}/include"
)
multiarch="${DEB_HOST_MULTIARCH:-x86_64-linux-gnu}"
gcc_lib=""
for ver in 14 13 12 11; do
  if [[ -d "/usr/include/c++/${ver}" ]]; then
    SWIFT_CXX_INCLUDES+=(
      -Xcxx -isystem -Xcxx "/usr/include/c++/${ver}"
      -Xcc -isystem -Xcc "/usr/include/c++/${ver}"
    )
    if [[ -d "/usr/include/${multiarch}/c++/${ver}" ]]; then
      SWIFT_CXX_INCLUDES+=(
        -Xcxx -isystem -Xcxx "/usr/include/${multiarch}/c++/${ver}"
        -Xcc -isystem -Xcc "/usr/include/${multiarch}/c++/${ver}"
      )
    fi
    if [[ -d "/usr/lib/gcc/${multiarch}/${ver}" ]]; then
      gcc_lib="/usr/lib/gcc/${multiarch}/${ver}"
    fi
    break
  fi
done
export LIBRARY_PATH="${CAPNP_PREFIX}/lib:${CAPNP_PREFIX}/lib64${gcc_lib:+:$gcc_lib}${LIBRARY_PATH:+:$LIBRARY_PATH}"

echo "[INFO] swift build -c release (mode=$MODE reps=$REPS seed=$BENCHMARK_SEED)"
swift build -c release "${SWIFT_CXX_INCLUDES[@]}" 2>&1

BIN="$(swift build -c release "${SWIFT_CXX_INCLUDES[@]}" --show-bin-path)/serializer-benchmark-swift"
echo "[INFO] $BIN ${ARGS[*]}"
"$BIN" "${ARGS[@]}"

bench_finish_runner Swift
