---
title: "Fortran"
---

# Fortran

The Fortran runner evaluates pure-Fortran interchange libraries (`JSON`, `TOML`, `MessagePack`, and a length-prefixed binary control) on the suite data set alongside official scientific array bindings (`HDF5`, `NetCDF-4`, `ADIOS2`, and `Arrow C Data Interface`) on dense `float64` grids.

## Runtime & Environment

The runner builds a single native batch executable via the Fortran Package Manager (`fpm`) and GNU Fortran (`gfortran` 13+). Memory comes from the process allocator with no garbage collector; `MemoryPeakBytes` is logged as `0` because the runner does not instrument allocator high-water marks. Pure-Fortran interchange libraries are separated deliberately from C/C++ FFI wrappers (which are studied independently in [Experiment 4: Fortran FFI tax](../experiments/index.md)). The language is specified by ISO/IEC 1539 (Fortran 2018 draft [18-007r1](https://j3-fortran.org/doc/year/18/18-007r1.pdf) from [WG5](https://wg5-fortran.org/)).

| Property | Configuration |
|---|---|
| Language / spec | ISO/IEC 1539 (Fortran 2018) |
| Build & toolchain | GNU Fortran 13+ (`gfortran-13`) and [fpm](https://fpm.fortran-lang.org/) 0.13 (`fortran/fpm.toml`) |
| Memory model | Process allocator; no garbage collector |
| Runner & logs | `fortran/scripts/run-benchmarks.sh` → `logs/fortran/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Schedule | Shared C `block_shuffle` (`c/src/schedule.c`) |
| Data sets | `suite`, `array` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [adios2](https://github.com/ornladios/ADIOS2) | `adios2` | `array` | `native` (file-only) | Official Fortran binding over C++ serial BP5 directory; `adios2_set_selection` for `grid_window` |
| [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/src/custom_binary.f90) | `custom` | `suite` | `bytes only` | In-tree little-endian length-prefixed control baseline |
| [fortran-messagepack](https://github.com/synthfi/fortran-messagepack) | `msgpack` | `suite` | `bytes only` | Pure-Fortran `pack_alloc` / `unpack`, including `int64` timestamps |
| [gld-arrow](https://github.com/leo-gan/gld-arrow-fortran) | `arrow` | `array` | `bytes only` | Arrow C Data Interface contiguous `float64` buffer; window sliced after import |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `array` | `bytes only` | Pure x86-64 Assembly Kiln Wire Format v2 (`ISO_C_BINDING`); KLNT v2 `grid` + strided `grid_window` |
| [hdf5-fortran](https://github.com/HDFGroup/hdf5) | `hdf5` | `array` | `bytes only` | Official HDF5 Fortran API on core virtual file driver (`H5Pset_fapl_core`); `H5Sselect_hyperslab` for `grid_window` |
| [jonquil](https://github.com/toml-f/jonquil) | `json` | `suite` | `bytes only` | `json_dumps` / `json_loads` over the `toml-f` document model |
| [json-fortran](https://github.com/jacobwilliams/json-fortran) | `json` | `suite` | `bytes only` | `json_core` compact serialize/deserialize; built with `-DINT64 -DREAL64` |
| [netcdf-fortran](https://github.com/Unidata/netcdf-fortran) | `netcdf` | `array` | `native` (file-only) | Official NetCDF-4 file write/read (`NF90_DOUBLE`); 1-based `start`/`count` for `grid_window` |
| [rojff](https://github.com/everythingfunctional/rojff) | `json` | `suite` | `bytes only` | `to_compact_string` / `parse_json_from_string`; default `int32` kind (64-bit ints exact below $2^{53}$) |
| [toml-f](https://github.com/toml-f/toml-f) | `toml` | `suite` | `bytes only` | `toml_serialize` / `toml_loads` (TOML 1.0) |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[adios2](https://github.com/ornladios/ADIOS2)** — adios2 is the official ADIOS2 Fortran binding over the C++ core. The build is serial, MPI is off, and the engine is BP5. BP5 writes a directory and the API has no bytes buffer. This row times one float64 variable named grid. grid_window sets a 0-based selection before get. The CSV mode is stream, StreamMode is native, and the size is the sum of the file sizes. It is published through config/file-only.txt. The row does not time the five suite types.
    - **[custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/src/custom_binary.f90)** — This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.
    - **[fortran-messagepack](https://github.com/synthfi/fortran-messagepack)** — fortran-messagepack is a pure Fortran MessagePack library. MessagePack exists as a compact binary form of JSON-like values. This row times pack_alloc and unpack. Integers are MessagePack integers, including int64 epoch milliseconds.
    - **[gld-arrow](https://github.com/leo-gan/gld-arrow-fortran)** — gld-arrow-fortran (leo-gan) implements the Apache Arrow C Data Interface in pure Fortran for contiguous float64 buffers on the `array` data set; `grid_window` slices after import.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) called directly from Fortran via `ISO_C_BINDING` (`bind(C)`). Covers `suite` (single + batch) and `array` (KLNT v2 `grid` + strided `grid_window`).
    - **[hdf5-fortran](https://github.com/HDFGroup/hdf5)** — hdf5-fortran is the official HDF5 Fortran API. This row times the array data set: one contiguous float64 dataset named grid, on the core virtual file driver with backing store off. The byte size is the flushed file image. grid_window reads an interior hyperslab. The row does not time the five suite types.
    - **[jonquil](https://github.com/toml-f/jonquil)** — Jonquil is a JSON library for Fortran, built on TOML Fortran. It exists so a Fortran program can parse and serialize JSON with the same document model as toml-f. This row times json_dumps and json_loads.
    - **[json-fortran](https://github.com/jacobwilliams/json-fortran)** — JSON-Fortran is a modern Fortran JSON API. It exists so Fortran programs can read and write JSON without calling a C library. This row times json_core serialize and deserialize. The runner builds it with -DINT64 and -DREAL64, so json_IK is int64 and json_RK is real64. Epoch milliseconds stay JSON integers.
    - **[netcdf-fortran](https://github.com/Unidata/netcdf-fortran)** — netcdf-fortran is the official NetCDF Fortran API. NF90_DISKLESS discards the file on close, so there is no buffer and no honest size. This row times one NF90_DOUBLE variable named grid in a real NetCDF-4 file. grid_window reads with a 1-based start and count. The CSV mode is stream, StreamMode is native, and the size is the file size. It is published through config/file-only.txt. The row does not time the five suite types.
    - **[rojff](https://github.com/everythingfunctional/rojff)** — rojff (Return of JSON for Fortran) is a pure Fortran JSON value tree. It was written to construct JSON faster than earlier Fortran JSON libraries, with functional constructors and a move API. This row times to_compact_string and parse_json_from_string. Its integer kind is the compiler's default integer, int32 here. Values outside that range are written as JSON numbers so the integer reader does not overflow, and are read back with nint.
    - **[toml-f](https://github.com/toml-f/toml-f)** — TOML Fortran is a TOML 1.0 parser and serializer for Fortran. It exists so Fortran projects can load and save configuration as TOML. This row times toml_serialize and toml_loads. A batch of more than one record is a table with a records array, because TOML has no bare array at the root. The JSON rows use the same envelope so one reader serves both.

## Measurement Caveats

- **Integer width differences:** `json-fortran` is built with `-DINT64` and `-DREAL64` (`fortran/scripts/fpm-env.sh`) so epoch-millisecond timestamps remain 64-bit JSON integers. `rojff` uses default 32-bit integers, writing larger values as JSON numbers read back with `nint` (exact up to $2^{53}$). `rojff` has no tagged release and is pinned to commit `9f68e5aa4c12`.
- **Multi-instance batch envelope:** Because TOML forbids a bare root array, $N > 1$ batches in Fortran wrap records inside a table containing a `records` array across TOML and JSON rows for reader uniformity. All text output is compact (no pretty-printing).
- **File-only scientific rows:** `netcdf-fortran` avoids `NF90_DISKLESS` (which discards the file on close and leaves no honest byte size) and times a real NetCDF-4 file. `adios2` writes a serial BP5 directory whose size is the sum of its files; IO and engine setup stay in `prepare`. Both rows emit `stream` / `native` only and are published via `config/file-only.txt`.
- **Excluded libraries:** C/C++ FFI wrappers (`fortran-yaml-c`, `fortran-yaml-cpp`, `YAJL-Fort`, `mpack-fortran`) are excluded from the pure-Fortran leaderboard because they time FFI marshaling plus a C codec. Unqualified or non-round-tripping libraries (`fson`, `jsonff`, `fortjson`, `yaFyaml`, `fortran-yaml`, `qfyaml`, `Fyaml`, `FoX`, `FoXy`, `xml-fortran`, `h5fortran`, `nc4fortran`, `csv-fortran`, `BeFoR64`, `VTKFortran`) are omitted.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Fortran)](../dashboard/index.html?lang=fortran&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Fortran)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Fortran: `json-fortran` vs. `rojff`](../analysis/call-sites/fortran-json-fortran-vs-rojff.md) · [Experiment 4: Fortran FFI tax](../experiments/index.md)
- **Build & run guide:** [`fortran/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/fortran/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
