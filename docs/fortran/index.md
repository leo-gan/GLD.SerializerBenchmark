---
title: "Fortran"
---

Fortran
===

Six rows are pure Fortran: three JSON libraries (json-fortran, jonquil, rojff), TOML (toml-f), MessagePack (fortran-messagepack), and an in-tree little-endian baseline (custom-binary). Those rows are **bytes**. `hdf5-fortran` is the official HDF5 Fortran API on the core virtual file driver, so it is also bytes. `netcdf-fortran` and `adios2` have no bytes API. Their CSV rows are `stream` / `native`, and they are published through `config/file-only.txt`.

Numbers for this language appear on the [Dashboard](../dashboard/?lang=fortran) after a publication run. These times cannot be ranked against another language.

## Runtime

### What it is

Fortran is the language of a large share of numerical and scientific programs. This suite runs a **batch program** built by [fpm](https://fpm.fortran-lang.org/) and executed as one process. It is not a compiler-runtime intrinsic and not a C library with a thin `iso_c_binding` shell.

| | This suite |
|---|---|
| Compiler | GNU Fortran **13 or newer**. `check-host-requirements.sh fortran` rejects gfortran 11 and 12. CI installs `gfortran-13` and that image's HDF5 Fortran package, which share one module format. |
| Packages | fpm 0.13 (`fortran/fpm.toml`) |
| Prepare | `./scripts/install-host-requirements.sh fortran` puts fpm in `~/.local/bin`. The compiler and zlib/zstd headers come from the system. |
| Run | `fortran/scripts/run-benchmarks.sh` |
| Memory | The process allocator. There is no garbage collector. `MemoryPeakBytes` is 0 because this runner does not sample the allocator. |

### What this suite runs

The timed call is the library's own string or buffer API: build the document, serialize, then parse that buffer back. Schema setup is not a separate step. These libraries do not compile a schema.

`custom-binary` is the control row. It is the suite's length-prefixed layout, not a format anyone else publishes.

### What changes the numbers

json-fortran is built with `-DINT64` and `-DREAL64`, so `json_IK` is int64 and epoch milliseconds stay JSON integers. rojff's integer kind is the compiler default, int32. Values outside that range are JSON numbers and are read back with `nint`. They are exact below 2^53. fortran-messagepack stores those timestamps as MessagePack integers.

`hdf5-fortran` times `H5Pset_fapl_core` with backing store off. The byte size is `H5Fget_file_image` after a global flush. Bool is int8 0/1. Strings are fixed-length 48-byte fields plus a length, because this HDF5 1.10 Fortran module does not export a variable-length string type. `netcdf-fortran` does not use `NF90_DISKLESS`: that flag discards the file on close, so there is no buffer and no honest size. The row times a real NetCDF-4 file. `adios2` is the official Fortran binding over the C++ core, serial, MPI off, engine BP5. BP5 writes a directory. The size is the sum of the file sizes.

A batch of more than one record is a table with a `records` array, including the JSON rows. TOML has no bare array at the root, and one envelope keeps the readers aligned.

Text is compact. Nothing is pretty-printed inside the timer.

### Suite-specific gotchas

`-DINT64` and `-DREAL64` are on the fpm command line (`fortran/scripts/fpm-env.sh`). The other Fortran dependencies are not `.F90` files, so those macros do not change their integer kind.

fpm's package name for this runner is `gld-fortran-bench`. It must not match a dependency name, or fpm will not fetch that dependency.

rojff is pinned to commit `9f68e5aa4c12b32720d4224f1ac279bfd7d77b93`. It has no GitHub release. The version column shows the short id `9f68e5aa4c12`.

### Where to go next

How to install the toolchain and run the benchmark: [`fortran/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/README.md). The compiler is [gfortran](https://gcc.gnu.org/fortran/). The package runner is [fpm](https://fpm.fortran-lang.org/).

## Benchmark runner

- Directory: `fortran/`
- Output: `logs/fortran/YYYY-MM-DD-HHMMSS.csv` (`Language=fortran`, times in **nanoseconds**)
- Runner: `fortran/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Smoke: json-fortran, message, the smoke repetition count
- Schedule: the C `block_shuffle` implementation (`c/src/schedule.c`), not a second shuffle
- Interchange rows are bytes. `netcdf-fortran` and `adios2` emit `stream` / `native` only.

## Serializers

| Name | Category | Package | Stream | Notes |
|------|----------|---------|--------|-------|
| [json-fortran](https://github.com/jacobwilliams/json-fortran) | JSON | jacobwilliams/json-fortran | bytes | `json_core` serialize / deserialize. Built with `-DINT64` so epoch milliseconds stay JSON integers |
| [jonquil](https://github.com/toml-f/jonquil) | JSON | toml-f/jonquil | bytes | `json_dumps` / `json_loads` on the toml-f model |
| [rojff](https://github.com/everythingfunctional/rojff) | JSON | everythingfunctional/rojff | bytes | `to_compact_string` / `parse_json_from_string`. int32 kind; wider integers are JSON numbers |
| [toml-f](https://github.com/toml-f/toml-f) | Text | toml-f/toml-f | bytes | `toml_serialize` / `toml_loads`. TOML 1.0 |
| [fortran-messagepack](https://github.com/synthfi/fortran-messagepack) | Binary | synthfi/fortran-messagepack | bytes | `pack_alloc` / `unpack`, including int64 |
| [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/src/custom_binary.f90) | Binary | harness | bytes | Little-endian length-prefixed baseline |
| [hdf5-fortran](https://github.com/HDFGroup/hdf5) | HDF5 | HDF-Group/hdf5 | bytes | Core virtual file driver. File image after a global flush |
| [netcdf-fortran](https://github.com/Unidata/netcdf-fortran) | NetCDF | Unidata/netcdf-fortran | file | Real NetCDF-4 file. Published as file-only. No bytes row |
| [adios2](https://github.com/ornladios/ADIOS2) | ADIOS2 | ornladios/ADIOS2 | file | Official Fortran binding, serial BP5 directory. Published as file-only |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the in-tree path this suite times). A version after the name is the `SerializerVersion` this runner writes.

#### [json-fortran](https://github.com/jacobwilliams/json-fortran) · `9.3.1`

JSON-Fortran is a modern Fortran JSON API. It exists so Fortran programs can read and write JSON without calling a C library. This row times `json_core` serialize and deserialize. The runner builds it with `-DINT64` and `-DREAL64`, so `json_IK` is int64 and `json_RK` is real64. Epoch milliseconds stay JSON integers.

#### [jonquil](https://github.com/toml-f/jonquil) · `0.3.2`

Jonquil is a JSON library for Fortran, built on TOML Fortran. It exists so a Fortran program can parse and serialize JSON with the same document model as toml-f. This row times `json_dumps` and `json_loads`.

#### [rojff](https://github.com/everythingfunctional/rojff) · `9f68e5aa4c12`

rojff (Return of JSON for Fortran) is a pure Fortran JSON value tree. It was written to construct JSON faster than earlier Fortran JSON libraries, with functional constructors and a move API. This row times `to_compact_string` and `parse_json_from_string`. Its integer kind is the compiler's default integer, int32 here. Values outside that range are written as JSON numbers so the integer reader does not overflow, and are read back with `nint`.

#### [toml-f](https://github.com/toml-f/toml-f) · `0.5.2`

TOML Fortran is a TOML 1.0 parser and serializer for Fortran. It exists so Fortran projects can load and save configuration as TOML. This row times `toml_serialize` and `toml_loads`. A batch of more than one record is a table with a `records` array, because TOML has no bare array at the root. The JSON rows use the same envelope so one reader serves both.

#### [fortran-messagepack](https://github.com/synthfi/fortran-messagepack) · `0.3.1`

fortran-messagepack is a pure Fortran MessagePack library. MessagePack exists as a compact binary form of JSON-like values. This row times `pack_alloc` and `unpack`. Integers are MessagePack integers, including int64 epoch milliseconds.

#### [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/src/custom_binary.f90) · `v2-1.0`

This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.

#### [hdf5-fortran](https://github.com/HDFGroup/hdf5) · `1.10.7`

hdf5-fortran is the official HDF5 Fortran API. This row times the core virtual file driver: backing store off, and the byte size is the flushed file image. Bool is an int8 0/1 dataset. Strings are fixed-length 48-byte fields plus an explicit length.

#### [netcdf-fortran](https://github.com/Unidata/netcdf-fortran)

netcdf-fortran is the official NetCDF Fortran API. `NF90_DISKLESS` discards the file on close, so this row times a real NetCDF-4 file. The CSV mode is stream, StreamMode is native, and the size is the file size. It is published through `config/file-only.txt`.

#### [adios2](https://github.com/ornladios/ADIOS2) · `2.10.2`

adios2 is the official ADIOS2 Fortran binding over the C++ core. The build is serial, MPI is off, and the engine is BP5. BP5 writes a directory and the API has no bytes buffer. The size is the sum of the file sizes. It is published through `config/file-only.txt`.

## Not registered

These were considered and left off the leaderboard.

- **fson** and **jsonff** are Fortran JSON libraries. jsonff was not built into this runner. fson is the older Fortran 95 stack and was not shown to round-trip the five suite types here.
- **fortjson** was not shown to round-trip the five suite types.
- **yaFyaml** parses a YAML subset for gFTL and can print a node. It needs gfortran 12 and gFTL. This runner did not qualify that print path on the five suite types. **fortran-yaml**, **qfyaml**, and NOAA **Fyaml** were not shown to round-trip those types either.
- **fortran-yaml-c**, **fortran-yaml-cpp**, **YAJL-Fort**, and **mpack-fortran** call C or C++ libraries. They measure that library plus an FFI crossing. They are not separate leaderboard rows.
- **FoX**, **FoXy**, and **xml-fortran** are XML. XML is outside the compliance catalog, and none of them was qualified on the five suite types.
- **h5fortran** and **nc4fortran** open a file name. They were not shown to select the HDF5 core driver or a NetCDF memory buffer, so they are not extra rows.
- **fortran-hdf5-interface** and **h5fortran-mpi** are not timed.
- **csv-fortran**, **BeFoR64**, and **VTKFortran** move arrays or meshes. They are not interchange standards in this catalog.
- There is no pure Fortran CBOR, Protocol Buffers, Avro, BSON, FlatBuffers, Ion, Arrow, or Parquet library in this runner.
