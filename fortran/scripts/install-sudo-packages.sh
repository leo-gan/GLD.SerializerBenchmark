#!/usr/bin/env bash
# Packages that need your password. Run this yourself:
#   ./fortran/scripts/install-sudo-packages.sh
#
# The pure-Fortran adapters (json-fortran, jonquil, rojff, toml-f,
# fortran-messagepack) build with the system gfortran 11.4 and the fpm
# binary already in ~/.local/bin. You do not need this script for that work.
#
# gfortran-12
#   Installed beside gfortran 11 as /usr/bin/gfortran-12. It does not replace
#   /usr/bin/gfortran. yaFyaml's docs ask for gfortran 12 or newer.
# libnetcdff-dev
#   Fortran bindings for the later NetCDF row. The C library is already
#   installed. On Ubuntu 22.04 this package is older than libnetcdf-dev;
#   say so if a later build cannot link them.
set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  APT=(apt-get)
else
  APT=(sudo apt-get)
fi

"${APT[@]}" update
"${APT[@]}" install -y gfortran-12 libnetcdff-dev

echo
echo "gfortran-12: $(gfortran-12 --version | head -1)"
dpkg -l libnetcdff-dev | awk '/^ii/{print $2, $3}'
echo "Default gfortran is still: $(gfortran --version | head -1)"
