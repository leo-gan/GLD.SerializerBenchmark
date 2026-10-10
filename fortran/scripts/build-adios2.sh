#!/usr/bin/env bash
# Build ADIOS2 v2.10.2 with the official Fortran bindings, MPI off, engine BP5.
# Installs into ~/.local so fpm-env.sh can add the module and library path.
# Does not commit the source tree.
set -euo pipefail

TAG="v2.10.2"
PREFIX="${ADIOS2_PREFIX:-${HOME}/.local}"
SRC="${ADIOS2_SRC:-/tmp/adios2-src}"
BUILD="${ADIOS2_BUILD:-/tmp/adios2-build}"

if [[ -x "${PREFIX}/bin/adios2-config" ]]; then
  echo "[OK] adios2-config already in ${PREFIX}/bin"
  exit 0
fi

FC="${FC:-${FPM_FC:-gfortran}}"
if command -v gfortran-13 >/dev/null 2>&1 && [[ "$FC" == "gfortran" ]]; then
  FC="gfortran-13"
fi

mkdir -p "$(dirname "$SRC")"
if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
  rm -rf "$SRC"
  git clone --depth 1 --branch "$TAG" https://github.com/ornladios/ADIOS2.git "$SRC"
fi

cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_Fortran_COMPILER="$FC" \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,${BUILD}/lib" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,${BUILD}/lib" \
  -DADIOS2_USE_MPI=OFF \
  -DADIOS2_USE_Fortran=ON \
  -DADIOS2_USE_Python=OFF \
  -DADIOS2_USE_SST=OFF \
  -DADIOS2_USE_DataMan=OFF \
  -DADIOS2_USE_SSC=OFF \
  -DADIOS2_USE_BZip2=OFF \
  -DADIOS2_USE_PNG=OFF \
  -DADIOS2_USE_Blosc2=OFF \
  -DADIOS2_USE_ZFP=OFF \
  -DADIOS2_USE_SZ=OFF \
  -DADIOS2_USE_MGARD=OFF \
  -DADIOS2_USE_LIBPRESSIO=OFF \
  -DADIOS2_USE_ZeroMQ=OFF \
  -DADIOS2_USE_HDF5=OFF \
  -DADIOS2_USE_IME=OFF \
  -DADIOS2_USE_Campaign=OFF \
  -DADIOS2_USE_Profiling=OFF \
  -DBUILD_TESTING=OFF \
  -DADIOS2_BUILD_EXAMPLES=OFF

cmake --build "$BUILD" -j"$(nproc 2>/dev/null || echo 2)"
cmake --install "$BUILD"
echo "[OK] ADIOS2 ${TAG} installed to ${PREFIX}"
