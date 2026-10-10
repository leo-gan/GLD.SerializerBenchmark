# Shared fpm flags for the Fortran runner. Source this from the benchmark scripts.
# json-fortran stores integers in json_IK. -DINT64 makes that int64 so epoch
# milliseconds stay JSON integers. -DREAL64 pins the real kind.
# Prefer gfortran 13. A conda prefix at ~/.local/gfortran13 is used only when
# its HDF5 and ADIOS2 modules are present, because those .mod files must be
# built by the same compiler. Otherwise use gfortran-13 from PATH with the
# system HDF5 and NetCDF modules (Ubuntu 24.04).
GF13="${HOME}/.local/gfortran13"
_use_prefix=0
# A prefix is usable only when this compiler can read its hdf5.mod. Conda
# packages sometimes ship a module file from a different gfortran.
_mod_ok() {
  local fc="$1" inc="$2"
  [[ -n "$inc" && -f "$inc/hdf5.mod" ]] || return 1
  printf 'use hdf5\nend\n' | "$fc" -fsyntax-only -I"$inc" -xf95 /dev/stdin >/dev/null 2>&1
}
if [[ -z "${FPM_FC:-}" ]]; then
  _h5inc=""
  if [[ -x "${GF13}/bin/gfortran" ]]; then
    _h5inc="$(dirname "$(find "${GF13}" -name 'hdf5.mod' -print -quit 2>/dev/null || true)")"
    if _mod_ok "${GF13}/bin/gfortran" "${_h5inc}"; then
      export FPM_FC="${GF13}/bin/gfortran"
      _use_prefix=1
    fi
  fi
  if [[ -z "${FPM_FC:-}" ]] && command -v gfortran-13 >/dev/null 2>&1; then
    export FPM_FC=gfortran-13
  fi
  if [[ -z "${FPM_FC:-}" ]]; then
    export FPM_FC=gfortran
  fi
elif [[ "${FPM_FC}" == "${GF13}/bin/gfortran" ]]; then
  _h5inc="$(dirname "$(find "${GF13}" -name 'hdf5.mod' -print -quit 2>/dev/null || true)")"
  if _mod_ok "${FPM_FC}" "${_h5inc}"; then
    _use_prefix=1
  fi
fi

_ff="-DINT64 -DREAL64"
_ld=""
if [[ "${_use_prefix}" -eq 1 ]]; then
  _h5="$(find "${GF13}" -name 'hdf5.mod' -print -quit)"
  _nc="$(find "${GF13}" -name 'netcdf.mod' -print -quit)"
  _ad="$(find "${GF13}" -name 'adios2.mod' -print -quit)"
  [[ -n "${_h5}" ]] && _ff="${_ff} -I$(dirname "${_h5}")"
  [[ -n "${_nc}" ]] && _ff="${_ff} -I$(dirname "${_nc}")"
  [[ -n "${_ad}" ]] && _ff="${_ff} -I$(dirname "${_ad}")"
  _ld="-L${GF13}/lib -Wl,-rpath,${GF13}/lib"
else
  if [[ -d /usr/include/hdf5/serial ]]; then
    _ff="${_ff} -I/usr/include/hdf5/serial"
  fi
  if [[ -f /usr/include/netcdf.mod ]]; then
    _ff="${_ff} -I/usr/include"
  fi
  if [[ -d "${HOME}/.local/include/adios2/fortran" ]]; then
    _ff="${_ff} -I${HOME}/.local/include/adios2/fortran"
  fi
  if [[ -d /usr/lib/x86_64-linux-gnu/hdf5/serial ]]; then
    _ld="-L/usr/lib/x86_64-linux-gnu/hdf5/serial"
  fi
  if [[ -d "${HOME}/.local/lib" ]]; then
    _ld="${_ld} -L${HOME}/.local/lib -Wl,-rpath,${HOME}/.local/lib"
  fi
fi
export FPM_FFLAGS="${_ff} ${FPM_FFLAGS:-}"
export FPM_LDFLAGS="${_ld} ${FPM_LDFLAGS:-}"
unset _ff _ld _h5 _nc _ad _use_prefix
