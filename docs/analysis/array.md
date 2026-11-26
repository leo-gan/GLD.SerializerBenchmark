# Array Data Set

The **`array`** data set evaluates scientific array containers (`HDF5`, `NetCDF-4`, `ADIOS2`, and Arrow numeric buffers) on dense two-dimensional `float64` grids and interior hyperslab reads. Cells execute via `config/library/array.yaml` and `array-smoke.yaml` with $N = 1$ and `compression.mode: none`.

## Motivation and Inclusion Policy

Small scalar records fail to characterize scientific container formats designed for multi-megabyte contiguous arrays and partial-slice I/O. A language is included on `array` only when a maintained library writes the full array and reads the interior window through its own API; ad-hoc FFI shims written solely for this repository are excluded.

## Data Types

```text
grid {
  values: float64[ny][nx]                  // nx = 512, ny = 512 (262,144 elements = 2 MiB raw)
}
grid_window {
  write:  identical full 512×512 array
  read:   values[y0 : y0 + wy][x0 : x0 + wx]   // x0 = 128, y0 = 64, wx = 256, wy = 128
}
```

Coordinates are 0-based with `y` outer and `x` inner (unit-interval `float64` values); Fortran follows column-major `values(nx, ny)` ordering. Fidelity requires **bit-identical `float64`** round trips, and `Size` records the full container size.

### `grid`

Writes and reads the complete $512 \times 512$ `float64` array (2 MiB of numeric data prior to container headers), isolating bulk scientific array serialization throughput and container overhead.

### `grid_window`

Writes the same $512 \times 512$ array as `grid`, then reads only the interior $256 \times 128$ rectangle using native partial selection (HDF5 hyperslab, NetCDF `start`/`count`, or ADIOS selection). A full read followed by a host-side slice is invalid except where explicitly caveated (`gld-hdf5`, `gld-arrow`).

## Language Coverage

Because NetCDF-4 uses HDF5 as its storage container, newly added languages register HDF5 only (Fortran and Python retain their published NetCDF-4 and ADIOS2 rows; ADIOS2's C/C++ engines underlie the existing Python and Fortran bindings).

| Language | HDF5 | NetCDF-4 | ADIOS2 | Notes |
|---|---|---|---|---|
| **C** | `hdf5` | — | — | HDF5 core driver (in-memory file image) |
| **C#** | `PureHDF` | — | — | Pure-managed .NET writer (no `libhdf5`) |
| **C++** | `highfive` | — | — | C++ HighFive wrapper over `libhdf5` |
| **Fortran** | `hdf5-fortran` | `netcdf-fortran` | `adios2` | Also times `gld-arrow` (Arrow C Data Interface) |
| **JavaScript** | `h5wasm` | — | — | WebAssembly `libhdf5` on Emscripten memory FS |
| **Mojo** | `gld-hdf5` | — | — | Pure-Mojo writer; `grid_window` slices after full read (`gld-netcdf`/`gld-adios2` stay on `suite`) |
| **Python** | `h5py` | `netCDF4` | `adios2` | `h5py` uses core driver; excludes `xarray`/`PyTables`/`h5netcdf` duplicates |
| **Rust** | `hdf5-metno` | — | — | Rust bindings to `libhdf5` |

**Languages not measured on `array`:** Go (`gonum.org/v1/hdf5` archived), Java/Kotlin (official HDF Group Java bindings require a native installer rather than Maven; JHDF is read-focused), PHP, Swift, and Zig (no maintained native HDF5 writers without custom C FFI shims).
