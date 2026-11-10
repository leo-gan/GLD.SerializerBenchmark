# Array

The **array** data set is `grid` and `grid_window`: one 512×512 float64 array, and an interior window of that array. These cells run from `array.yaml` and `array-smoke.yaml`. `all@` does not include them. N stays 1. Other languages do not receive these type ids from `default.yaml` or `smoke.yaml`.

## Why this set

The array set is one dense grid of numbers, plus a read of a window inside that grid. It exists so scientific file formats are compared on the job they were built for, instead of on a small message. A message of a few fields does not show the cost of writing 262,144 floats (2 MiB), or of reading a rectangle out of them. Typical uses are images, maps, and simulation grids. The five suite records are not part of this set. N stays 1 because the array is one value. The batch size is not a row count here.

A language is measured on this set when a maintained library writes that array and reads the window through its own API. A one-off call into the C library, written only for this benchmark, is not a member of the set.

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

```text
grid {
  values: float64[y][x]    // nx = 512, ny = 512
}
grid_window {
  same write
  read: values[y0 : y0+wy][x0 : x0+wx]
  // x0 = 128, y0 = 64, wx = 256, wy = 128
}
```

Coordinates are 0-based. Fill order is `y` outer, `x` inner, one unscaled unit-interval float64 per element. Fortran stores `values(nx, ny)`, and the file dimensions follow that array: `x` then `y`. Fidelity is bit-identical float64. The size column is the full file.

## grid

A grid is one 512 by 512 array of 64-bit floats, written and read in full. That is 2 MiB of numbers before any file wrapper. It exists so array file formats are timed on a real grid rather than on a handful of fields. Typical uses are a raster, a map layer, or a simulation field.

## grid_window

Grid window writes the same array as `grid`, and the read returns only an interior rectangle. It exists because scientific formats can fetch a window without copying the whole array. A second type is required for that question. One score for `grid` would mix a full read and a window read. A full read followed by a slice on the host is not a `grid_window` result. Typical uses are viewing a region of a map or a tile of a larger field. `grid_window` writes the whole array and reads the window with a hyperslab, a NetCDF `start`/`count`, or an ADIOS selection.

## Measured on this set

NetCDF-4 files are HDF5 files. A second NetCDF row in a language that already times HDF5 would measure the same container again, so new languages on this set are HDF5 only. Fortran and Python keep the NetCDF and ADIOS2 rows that were already published. ADIOS2’s own libraries are C++, C, Fortran, Python, and Matlab. No further ADIOS2 row is added: the C and C++ engines are the same library Fortran and Python already call, and the other languages have no library for it.

| Language | HDF5 | NetCDF | ADIOS2 |
|----------|------|--------|--------|
| C | `hdf5` | | |
| C++ | `highfive` | | |
| C# | `PureHDF` | | |
| Fortran | `hdf5-fortran` | `netcdf-fortran` | `adios2` |
| JavaScript | `h5wasm` | | |
| Python | `h5py` | `netCDF4` | `adios2` |
| Rust | `hdf5-metno` | | |
| Mojo | `gld-hdf5` | | |

`hdf5` uses the HDF5 core driver and returns the file image. `highfive` and `hdf5-metno` write a file and return those bytes. `h5wasm` uses the WebAssembly memory filesystem. `PureHDF` is a managed writer, not libhdf5, and the bytes path returns the file bytes, so the size is the file length. `gld-hdf5` is a from-scratch Mojo writer, not libhdf5. It writes one contiguous float64 dataset. `grid_window` copies the interior window after `read_hdf5` returns the whole file, because that library has no hyperslab. The other window reads are a hyperslab, a slice, or a selection. These rows do not time the five suite types. Fortran also times `gld-arrow` on the same grid: Arrow C Data Interface numeric buffers, not an HDF5 file. Mojo `gld-netcdf` and `gld-adios2` are not array rows.

## Not measured on this set

| Language | Why there is no row |
|----------|---------------------|
| Go | `gonum.org/v1/hdf5` is archived. There is no maintained writer for this set. |
| Java | The HDF Group Java library is a native installer, not a Maven dependency this runner can build. JHDF is read-focused. |
| Kotlin | A Kotlin row would call the Java libraries. Those are not on this set. |
| PHP | No maintained writer. |
| Swift | No maintained writer. A C import would time libhdf5 plus an FFI crossing this suite did not write a library for. |
| Zig | No maintained writer. The same FFI crossing applies. |

PyTables, xarray, h5netcdf, and SciPy’s classic NetCDF reader are not extra Python rows. xarray is not a format. The others sit on HDF5 or on NetCDF-3, and Python already times `h5py` and `netCDF4`.
