# Array bindings by language

The array data set is `grid` and `grid_window`: one 512×512 float64 array, and an interior window of that array. A row is registered only when the language has a maintained library that writes that array and reads the window back through its own API. A one-off call into the C library is not a separate row.

Fortran already times `hdf5-fortran`, `netcdf-fortran`, and `adios2`. This page is the survey for the other languages.

## Registered

| Language | HDF5 | NetCDF | ADIOS2 |
|----------|------|--------|--------|
| Fortran | `hdf5-fortran` | `netcdf-fortran` | `adios2` |
| Python | `h5py` | `netCDF4` | `adios2` |

Python `h5py` uses the HDF5 core driver. `netCDF4` writes a NetCDF-4 file. `adios2` is the official Python API and writes a serial BP5 directory. All three are bytes rows on `config/library/array.yaml`. They do not time the five suite types.

## Not registered

| Language | Why there is no row |
|----------|---------------------|
| C | The HDF Group C API, the Unidata NetCDF C API, and the ADIOS2 C API are the libraries the other bindings call. This suite already times those libraries from Fortran and Python. A C row would be the same library again. |
| C++ | HDF5's C++ API, netCDF-CXX4, and ADIOS2's C++ API are the native cores. ADIOS2's C++ core is what the Fortran and Python rows call. A second timing of that core is not a new standard. |
| C# | PureHDF reads and writes HDF5, and several NetCDF packages are P/Invoke over the C library. There is no maintained ADIOS2 binding. The set is not complete enough for one comparison cell. |
| Go | `gonum.org/v1/hdf5` is archived. Pure-Go HDF5 writers are incomplete. Go NetCDF libraries are either classic-format only or cgo. ADIOS2 has no Go binding. |
| Java | The HDF Group ships a Java binding, and Unidata ships NetCDF-Java. ADIOS2 does not. The three standards would not be the same set. |
| JavaScript | `h5wasm` and `jsfive` cover HDF5 reads, and `netcdfjs` reads NetCDF. None of them is a maintained writer for all three standards. ADIOS2 has no JavaScript binding. |
| Kotlin | A Kotlin row would call the Java libraries. Those Java libraries are not registered, for the reason above. |
| Mojo | No HDF5, NetCDF, or ADIOS2 library. |
| PHP | No maintained writer for these formats. |
| Rust | The `hdf5` and `netcdf` crates bind the C libraries. ADIOS2 has no Rust binding. The set is not complete. |
| Swift | No maintained writer. Calling HDF5 or NetCDF through a C import would time the C library plus an FFI crossing. |
| Zig | No maintained writer. The same FFI crossing applies. |

ADIOS2's own bindings are C++, C, Fortran, Python, and Matlab. Languages outside that list stay off this data set.
