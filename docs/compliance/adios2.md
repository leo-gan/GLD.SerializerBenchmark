# ADIOS2

ADIOS2 BP5 stores one dataset as a directory. The metadata index file in
that directory is named `md.idx`. The engine is documented in the
[ADIOS2 engine guide](https://adios2.readthedocs.io/en/v2.10.2/engines/engines.html).

There is no official OSI-licensed parse corpus in this suite. BP5 is a
directory, not a single byte buffer, so these cases are original marker
checks: the index name is present, and a missing index is rejected. They
are not a full BP5 conformance suite. No adapter is required to score
them. An empty cell stays empty.

## Versions

| Version | Parser-visible difference |
|---------|---------------------------|
| BP5 | Directory layout. The metadata index is `md.idx`. |

## What the cases cover

- The metadata index name `md.idx`
- The companion metadata file name `md.0`
- Rejects: an empty name, which stands for a directory with no `md.idx`

Catalog: `compliance/data/adios2/`. Inputs are UTF-8 file-name markers.

## Fortran serializer

`adios2` times the official Fortran binding on the array data set
(`grid` and `grid_window`). The build is serial, MPI is off, and the
engine is BP5. The binding has no bytes
buffer. The benchmark publishes the directory timing through
`config/file-only.txt`. It does not decode this corpus.
