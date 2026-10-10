# NetCDF

NetCDF is a binary scientific data file. A classic file starts with the
three ASCII bytes `CDF` and a version byte (`0x01` or `0x02`). A NetCDF-4
file is an HDF5 file and starts with the HDF5 signature. The format notes
are in the
[NetCDF format specifications](https://docs.unidata.ucar.edu/netcdf-c/current/file_format_specifications.html).

There is no official OSI-licensed parse corpus in this suite. The cases
under `compliance/data/netcdf/` are original. They check those signatures
and a truncated header. They are not a full NetCDF conformance suite.
No adapter is required to score them. An empty cell stays empty.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| classic | Magic `CDF` and version `0x01`. |
| 64-bit offset | Magic `CDF` and version `0x02`. |
| NetCDF-4 | The HDF5 signature. The file is HDF5 with NetCDF-4 conventions. |

## What the cases cover

- Classic and 64-bit-offset signatures
- A NetCDF-4 / HDF5 signature
- Rejects: a two-byte truncated classic header

Catalog: `compliance/data/netcdf/`. Inputs are hex.

## Fortran serializer

`netcdf-fortran` times the official Fortran API on a real NetCDF-4 file.
`NF90_DISKLESS` discards the file on close, so that flag is not a bytes
row. The benchmark publishes the file timing through `config/file-only.txt`.
It does not decode this corpus.
