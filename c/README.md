# C Serializer Benchmark

Native C harness emitting timestamped `logs/c/YYYY-MM-DD-HHMMSS.csv` (nanoseconds, `Language=c`).

## Serializers (19)

See [docs/c/index.md](../docs/c/index.md) for the inventory (JSON / binary / schema). Registered entries use real library APIs (or documented in-tree codecs where noted).

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

## Dependencies

```bash
./c/scripts/fetch-and-build-deps.sh   # once; vendors + builds static deps
```

Requires: `cmake`, `curl`, `pkg-config`, `libjson-c-dev` (or equivalent), `zlib`, `liblzma` for avro-c.

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
