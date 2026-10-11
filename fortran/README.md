# Fortran runner

Six pure-Fortran rows are bytes on the suite types: json-fortran, jonquil, rojff, toml-f, fortran-messagepack, and custom-binary. `hdf5-fortran`, `netcdf-fortran`, and `adios2` time the array data set (`grid`, `grid_window`) from `config/library/array.yaml`. `hdf5-fortran` is bytes on the HDF5 core driver. `netcdf-fortran` and `adios2` are file-only (stream/native). The compiler check requires gfortran 13.

GNU Fortran 11 or newer, zlib, libzstd, and [fpm](https://fpm.fortran-lang.org/) 0.13.

```bash
# Compiler and headers, once, if they are missing (uses sudo):
#   sudo apt-get install gfortran zlib1g-dev libzstd-dev
./scripts/install-host-requirements.sh fortran   # fpm into ~/.local/bin
./scripts/check-host-requirements.sh fortran
./fortran/scripts/run-benchmarks.sh smoke        # json-fortran, message
./fortran/scripts/run-benchmarks.sh all-single   # suite rows, 10 repetitions
./fortran/scripts/run-benchmarks.sh full         # suite rows, 100 repetitions
# Array data set (grid and grid_window). Not part of the suite matrix.
BENCHMARK_RUN_CONFIG=config/library/array-smoke.yaml \
  ./fortran/scripts/run-benchmarks.sh smoke "hdf5-fortran,netcdf-fortran,adios2"
```

`FPM_FC` selects the compiler. The default is `gfortran`.

`fortran/scripts/install-sudo-packages.sh` installs gfortran-12 and the NetCDF Fortran development package. The six registered libraries do not need it. gfortran-12 does not replace `/usr/bin/gfortran`.

The dependency-free round trip (schedule golden vector, custom-binary, UTF-8) is the CMake target `test_roundtrip`:

```bash
cmake -S fortran -B fortran/build-cmake -DCMAKE_BUILD_TYPE=Release
cmake --build fortran/build-cmake
./fortran/build-cmake/test_roundtrip
```

fpm builds the benchmark, because that executable links the Fortran packages in `fortran/fpm.toml`.
