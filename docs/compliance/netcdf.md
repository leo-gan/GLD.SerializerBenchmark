# NetCDF

NetCDF is a binary scientific data file. A classic file starts with the
three ASCII bytes `CDF` and a version byte (`0x01` or `0x02`). A NetCDF-4
file is an HDF5 file and starts with the HDF5 signature. The format notes
are in the
[NetCDF format specifications](https://docs.unidata.ucar.edu/netcdf-c/current/file_format_specifications.html).

There is no official OSI-licensed parse corpus in this suite. The cases
under `compliance/data/netcdf/` are original minimal files frozen from
netCDF4 1.7.4 (one dimension `x` of length 1, variable `v` float64 = 1),
plus a two-byte truncated header. They are not a full NetCDF conformance
suite. Each mapped row opens those bytes with that library: `netCDF4.Dataset`,
`nf90_open`, or gld-netcdf (`read_cdf1` for classic, no CDF-2 reader, and
`read_nc4` for the HDF5 signature). A four-byte magic prefix is not a file
these libraries open. An empty cell is a missing adapter.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| classic | Minimal classic file. Magic `CDF` and version `0x01`. |
| 64-bit offset | Minimal 64-bit-offset file. Magic `CDF` and version `0x02`. |
| NetCDF-4 | Minimal NetCDF-4 file. HDF5 signature, superblock version 2. |

## What the cases cover

- A minimal classic file and a minimal 64-bit-offset file
- A minimal NetCDF-4 file
- Rejects: a two-byte truncated classic header

Catalog: `compliance/data/netcdf/`. Inputs are hex.

## Fortran serializer

`netcdf-fortran` times the official Fortran API on the array data set
(`grid` and `grid_window`) as a real NetCDF-4 file.
`NF90_DISKLESS` discards the file on close, so that flag is not a bytes
row. The benchmark publishes the file timing through `config/file-only.txt`.
Its compliance cell calls `nf90_open` on this corpus.
