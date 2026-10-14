# HDF5

HDF5 is a binary container for named datasets and groups. A file starts
with the 8-byte signature `89 48 44 46 0d 0a 1a 0a` (`\x89HDF\r\n\x1a\n`).
The next byte is the superblock version. The format is specified by
[HDF5 File Format Specification](https://support.hdfgroup.org/documentation/hdf5/latest/group___f_m_t3.html).

There is no official OSI-licensed parse corpus in this suite. The cases
under `compliance/data/hdf5/` are original. They check the signature and
a versioned superblock prefix. They are not a full HDF5 conformance suite.
Each mapped row calls that library. libhdf5 bindings call `H5Fis_hdf5`
(or `h5py.is_hdf5`, or `h5fis_hdf5_f`). PureHDF opens with `H5File.Open`.
h5wasm opens with `h5wasm.File` and treats a negative `file_id` as a
reject, because that build does not export `H5Fis_hdf5`. gld-hdf5 calls
`read_hdf5`, which requires a superblock version 0 file of at least 96
bytes, so the 9-byte accepts fail. An empty cell is a missing adapter.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| superblock 0 | Signature plus version byte `0x00`. |
| superblock 2 | Signature plus version byte `0x02`, the common modern superblock. |

## What the cases cover

- The 8-byte signature followed by superblock version 0
- The same signature followed by superblock version 2
- Rejects: a four-byte truncated signature, and a buffer that does not start with the signature

Catalog: `compliance/data/hdf5/`. Inputs are hex.

## Fortran serializer

`hdf5-fortran` times the official Fortran API on the array data set
(`grid` and `grid_window`): one float64 dataset, core virtual file driver.
That row is a benchmark measurement. Its compliance cell calls
`h5fis_hdf5_f` on the same corpus.
