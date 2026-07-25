# C Serializer Benchmark

Native C benchmark runner emitting timestamped `logs/c/YYYY-MM-DD-HHMMSS.csv` (nanoseconds, `Language=c`).

## Serializers (20)

See [docs/c/index.md](../docs/c/index.md) for the inventory (JSON / binary / schema), visitor domain layer (`v2_codec`), and caveats. Includes official Google **libprotobuf** (`protobuf` row) when the protobuf sysroot is present.

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

## Dependencies

```bash
./c/scripts/fetch-and-build-deps.sh   # once; vendors + builds static deps
./cpp/scripts/setup-protobuf-sysroot.sh   # once; Google libprotobuf for the protobuf row
```

Requires: `cmake`, `curl`, `pkg-config`, `libjson-c-dev` (or equivalent), `zlib`, `liblzma` for avro-c; C++17 compiler for the Google protobuf module.

## Build & run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

## Tests

```bash
cmake -S c -B c/build -DCMAKE_BUILD_TYPE=Release
cmake --build c/build --target c_serializer_tests
./c/build/c_serializer_tests
```

Analysis: `analyze-benchmarks -l c` (see root README).

