# HDF5

HDF5 is a binary container for named datasets and groups. A file starts
with the 8-byte signature `89 48 44 46 0d 0a 1a 0a` (`\x89HDF\r\n\x1a\n`).
The next byte is the superblock version. The format is specified by
[HDF5 File Format Specification](https://support.hdfgroup.org/documentation/hdf5/latest/group___f_m_t3.html).

There is no official OSI-licensed parse corpus in this suite. The cases
under `compliance/data/hdf5/` are original. They check the signature and
a versioned superblock prefix. They are not a full HDF5 conformance suite.
No adapter is required to score them. An empty cell stays empty.

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

`hdf5-fortran` times the official Fortran API on the core virtual file
driver. That row is a benchmark measurement. It does not decode this corpus.
Bool is stored as int8 because the HDF5 1.10 Fortran API has no bool type.
Strings in that row are fixed-length fields plus an explicit length.
