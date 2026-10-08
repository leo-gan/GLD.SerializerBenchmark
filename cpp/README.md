# C++ Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

Native C++20 benchmark runner emitting timestamped `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (`Language=cpp`, nanoseconds).

## Serializers (39 with Arrow)

See [docs/cpp/index.md](../docs/cpp/index.md) for the inventory, optimal call paths, and **C vs C++ dual-use** notes.

Includes official **libprotobuf** (`protobuf`) plus in-tree **protobuf-wire**, and the four **Dagr** layout rows (`dagr-packed`, `dagr-regular`, `dagr-frozen`, `dagr-frozen-packed`) from the header-only code generated into `cpp/dagr_gen/` (regenerate with `dagr build` in `schemas/v2/dagr/`, like every other language).

With Arrow 25.0.1 on `ARROW_ROOT`, this machine registers **39** codecs: **33** existing rows (the four Dagr rows included; Boost.Serialization is not installed; avro-c and Cap'n Proto are) plus `sbe` and `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed`. Without that prefix the five Arrow rows are skipped and `sbe` still registers.

Columnar and SBE rows time `serialize_bytes` / `deserialize_bytes`. Building the Arrow table and filling the SBE flyweight happen inside the timed serialize call. Stream entry points are adapted wrappers around those bytes. The columnar run config is bytes only. There is no compliance decoder for `table`, `table_project`, `nested_table`, or `signal`.

`parquet` leaves compression at the Arrow C++ writer default. On 25.0.1 that default is **UNCOMPRESSED** (not Snappy). `parquet-uncompressed` sets `Compression::UNCOMPRESSED` explicitly. At N=100 both payloads are 25394 bytes and both column chunks report UNCOMPRESSED.

`orc` leaves compression at `arrow::adapters::orc::WriteOptions`. That default is **UNCOMPRESSED** (`ORCFileReader::GetCompression()`). It is not the Apache ORC C++ Zlib default. `orc-uncompressed` sets UNCOMPRESSED explicitly. At N=100 both payloads are 19463 bytes.

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`, `table`, `table_project`, `nested_table`, `signal`.

## Dependencies

CMake **FetchContent** pulls pinned libraries into `cpp/third_party/` on first configure (see `third_party/VERSIONS.md`). Requires network once, `cmake` ≥ 3.16, `g++`/`clang++` with C++20, `git`.

Apache Arrow is optional and is **not** FetchContent. Configure with `-DARROW_ROOT=` pointed at a prebuilt prefix (jammy apt packages `libarrow-dev` and `libparquet-dev` 25.0.1-1; ORC is inside `libarrow`). Configure still succeeds when the prefix is missing.

SBE 1.40.2 codecs are vendored headers under `cpp/gen/sbe/`, generated from `schemas/v2/sbe/signal.xml`. `nested_table` is absent from that schema, so `sbe` does not support it.

For official Google Protocol Buffers C++ (no root install):

```bash
./cpp/scripts/setup-protobuf-sysroot.sh
```

```bash
./scripts/check-host-requirements.sh cpp
```

## Build & run

```bash
./cpp/scripts/run-benchmarks.sh smoke
./cpp/scripts/run-benchmarks.sh full
```

Or:

```bash
cmake -S cpp -B cpp/build -DCMAKE_BUILD_TYPE=Release -DARROW_ROOT=/usr
cmake --build cpp/build -j
./cpp/build/serializer_benchmark_cpp --reps 10 --log-dir logs/cpp

`-DARROW_ROOT=/usr` matches a system install of `libarrow-dev` / `libparquet-dev`. Omit it, or point it at another prefix, when those packages are not installed. The benchmark binary's RPATH includes that prefix's `lib` directory.
```

## Tests

```bash
cmake --build cpp/build --target cpp_serializer_tests
./cpp/build/cpp_serializer_tests
```

Analysis: `analyze-benchmarks -l cpp`.

