# Apache Fory benchmarks

All Fory dependencies are pinned to **1.7.4**, the latest stable release verified
on September 22, 2026. Release candidates are excluded. The adapters cover nine
language entries; JavaScript and TypeScript use the same
`@apache-fory/core` runtime.

New runs use the versions below. Archived dashboard results and their source
catalog retain the library versions used for those measurements.

| Language ID | Dependency                       | Input                                    |
| ----------- | -------------------------------- | ---------------------------------------- |
| java        | `org.apache.fory:fory-core`      | Java objects                             |
| kotlin      | `org.apache.fory:fory-kotlin`    | Kotlin data classes                      |
| python      | `pyfory`                         | Python dataclasses                       |
| go          | `github.com/apache/fory/go/fory` | Go structs and slices                    |
| rust        | `fory`                           | Rust structs with `ForyStruct`           |
| cpp         | `apache/fory`, tag `v1.7.4`      | C++ structs and vectors                  |
| javascript  | `@apache-fory/core`              | JavaScript objects with declared schemas |
| csharp      | `Apache.Fory`                    | C# classes with `ForyStruct`             |
| swift       | `apache/fory`, tag `1.7.4`       | Swift structs with `ForyStruct`          |

## Run

Prepare the toolchains listed in each language guide, then run from the repository root:

```bash
# Fory only, all integrated languages, the default five-type matrix.
./scripts/run-fory-benchmarks.sh all-single

# One language, using its normal benchmark runner.
./scripts/run-fory-benchmarks.sh all-single rust
./python/scripts/run-benchmarks.sh all-single fory

# Full repetitions with a chosen workload configuration.
BENCHMARK_RUN_CONFIG="$PWD/config/library/default.yaml" \
  ./scripts/run-fory-benchmarks.sh full
```

The default matrix includes `message`, `document`, `telemetry`, `strings`, and
`event`, at instance counts 1 and 100. Results are written to
`logs/<language>/<timestamp>.csv`. Smoke mode uses each existing runner's smoke
defaults; use `all-single` for coverage of all five types and both instance counts.

Java and Kotlin use JDK 21. Kotlin uses Kotlin 2.3.20 and KSP 2.3.12.
Go requires Go 1.25 or newer. The configuration tools require Python 3 with PyYAML.

Swift requires Swift 6 or newer and Cap'n Proto 1.0.2 for the existing suite.
The locked IkigaJSON dependency uses macOS 26 APIs and experimental Swift
lifetime features; the complete suite cannot currently build on macOS 15.
C++ uses CMake and a C++20 compiler; with CMake 4, configure with
`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` for older third-party build files.
If the existing Cap'n Proto adapter fails to compile under Clang, its optional
build can be disabled before running the Fory benchmark:

```bash
cmake -S cpp -B cpp/build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBENCH_CPP_CAPNP=OFF
./scripts/run-fory-benchmarks.sh all-single cpp
```

## Measurement contract

Type registration, schema creation, fixture conversion, and initial round-trip
validation happen outside timing. Every measured decode is checked against the
input outside the timer.

Java, Kotlin, Python, Go, Rust, and C++ use Fory native mode with matching
schemas. C#, Swift, and JavaScript use their Fory cross-language encoding.
These are within-language benchmarks, not cross-language wire compatibility
tests. Different modes and object models can produce different encoded sizes.

Stream rows are marked `adapted` when the codec buffers bytes around stream I/O.
JavaScript publishes bytes rows only. C# retains the suite's existing
Base64 string and adapted stream modes. Rust uses the harness's reusable output
buffer. Smoke timings establish executable coverage and fidelity, not comparative
performance rankings.
