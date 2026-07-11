# C++ Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

Native C++20 harness emitting timestamped `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (`Language=cpp`, nanoseconds).

## Serializers (26+)

See [docs/cpp/index.md](../docs/cpp/index.md) for the inventory, optimal call paths, and **C vs C++ dual-use** notes.

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

## Dependencies

CMake **FetchContent** pulls pinned libraries into `cpp/third_party/` on first configure (see `third_party/VERSIONS.md`). Requires network once, `cmake` ≥ 3.16, `g++`/`clang++` with C++20, `git`.

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
cmake -S cpp -B cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build cpp/build -j
./cpp/build/serializer_benchmark_cpp --reps 10 --log-dir logs/cpp
```

## Tests

```bash
cmake --build cpp/build --target cpp_serializer_tests
./cpp/build/cpp_serializer_tests
```

Analysis: `analyze-benchmarks -l cpp`.
