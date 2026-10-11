# Array bindings by language

The array data set is `grid` and `grid_window`: one 512×512 float64 array, and an interior window of that array. A row is registered when a maintained library writes that array and reads the window through its own API. A one-off call into the C library, written only for this benchmark, is not a row.

NetCDF-4 files are HDF5 files. A second NetCDF row in a language that already times HDF5 would measure the same container again, so new languages on this track are HDF5 only. Fortran and Python keep the NetCDF and ADIOS2 rows that were already published. ADIOS2's own bindings are C++, C, Fortran, Python, and Matlab. No further ADIOS2 row is added: the C and C++ engines are the same library Fortran and Python already call, and the other languages have no binding.

## Registered

| Language | HDF5 | NetCDF | ADIOS2 |
|----------|------|--------|--------|
| C | `hdf5` | | |
| C++ | `highfive` | | |
| C# | `PureHDF` | | |
| Fortran | `hdf5-fortran` | `netcdf-fortran` | `adios2` |
| JavaScript | `h5wasm` | | |
| Python | `h5py` | `netCDF4` | `adios2` |
| Rust | `hdf5-metno` | | |

`hdf5` uses the HDF5 core driver and returns the file image. `highfive` and `hdf5-metno` write a file and return those bytes. `h5wasm` uses the WebAssembly memory filesystem. `PureHDF` is a managed writer, not libhdf5, and the C# string path carries the file bytes as Latin-1 so the size is the file length. Every window read is a hyperslab, a slice, or a selection. These rows do not time the five suite types.

## Not registered

| Language | Why there is no row |
|----------|---------------------|
| Go | `gonum.org/v1/hdf5` is archived. There is no maintained writer for the array contract. |
| Java | The HDF Group Java binding is a native installer, not a Maven dependency this runner can build. JHDF is read-focused. |
| Kotlin | A Kotlin row would call the Java libraries. Those are not registered. |
| Mojo | No HDF5 library. A hand-written C FFI is not a separate row. |
| PHP | No maintained writer. |
| Swift | No maintained writer. A C import would time libhdf5 plus an FFI crossing this suite did not write a library for. |
| Zig | No maintained writer. The same FFI crossing applies. |

PyTables, xarray, h5netcdf, and SciPy's classic NetCDF reader are not extra Python rows. xarray is not a format. The others sit on HDF5 or on NetCDF-3, and Python already times `h5py` and `netCDF4`.
