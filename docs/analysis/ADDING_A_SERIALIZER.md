# Adding a Serializer

This checklist specifies how to register and validate a new serialization library inside an **existing** language tree. To onboard an entire new language runtime, see [Adding a language](ADDING_A_LANGUAGE.md). Background specifications: [Architecture](architecture.md) · [Timing contract](TIMING_HONESTY.md) · [I/O & run modes](modes.md) · [Metrics catalog](METRICS.md).

## Prerequisites and Design Rules

1. **Default format configuration:** Benchmark the library's documented default wire settings rather than hand-tuned non-standard options, unless registering an explicit variant row (such as `parquet-uncompressed`).
2. **Domain isolation:** Avoid hard-coding suite type names inside wrappers when generic or reflection-bound APIs work; keep generated IDL types (`.proto`, `.fbs`, `.avsc`) in dedicated generated directories.
3. **Correctness:** Round-trip execution must achieve `FidelityScore = 1.0`. Prefer native wire formats over JSON envelopes; any unavoidable envelope must be disclosed on the language overview page.
4. **Runtime version reporting:** Populate CSV `SerializerVersion` dynamically from the installed package, crate, or assembly metadata rather than a hard-coded string.

### Timing Honesty {#timing-honesty}

Every new adapter must satisfy [Timing contract](TIMING_HONESTY.md):

- **Untimed (`prepare` / `Initialize`):** Schema loading/compilation, codec construction, type binding (`MakeGenericType`, `RuntimeTypeModel`, `ClassCache`), domain-to-native conversion, and reusable buffer allocation. Never pre-encode wire bytes here.
- **Timed (`serialize` / `deserialize`):** Only encode and decode of all $N$ instances specified by `DataTypeInstanceCount`.
- **Stream honesty:** Emit `StreamMode=native` or `text_on_stream` only when both halves use the library's streaming API; tag full-buffer wrappers `adapted` (or emit `bytes` only if the language runner is bytes-only).

### Hot-Path Implementation Before Publishing {#hot-path-before-full-matrix-required}

Correctness and the library's documented high-throughput call path must land together in the initial PR—do not merge a minimal getting-started snippet that allocates a fresh encoder per repetition and defers optimization.

| Preferred Hot-Path Practice | Avoid Inside Timed Loops |
|---|---|
| Bind typed/generic writers once in `prepare` (`Writer<T>`, monomorphic closures) | Dynamic `object`/untyped entry points that re-resolve metadata every call |
| Cache schemas, reflection maps, and encoder/decoder instances across repetitions | Calling `new BinaryEncoder(stream)` or `parse_schema` per repetition |
| Reuse output buffers and decode-into target objects where the API supports it | Allocating fresh scratch buffers or intermediate `Value` trees when a direct typed path exists |

**Worked example (`Apache.Avro` in C#):** The initial C# implementation called `ReflectDefaultWriter` + `Read<object>` and allocated new `BinaryEncoder`/`BinaryDecoder` instances per call, making `message@n=1` roughly $4\times$ slower than necessary. Switching to compiled `ReflectWriter<T>` / `ReflectReader<T>` bound once in `Initialize` with a shared `ClassCache` and reused encoder/decoder (`c-sharp/src/Serializers/ApacheAvroSerializerSer.cs`) eliminated the overhead while preserving domain isolation.

## Implementation Checklist

### 1. Add Dependency

Add the library to the language's manifest with a stable version pin and confirm a clean build:

| Language | Manifest & Build Command | Wrapper Directory |
|---|---|---|
| C | `c/scripts/fetch-and-build-deps.sh` / `CMakeLists.txt` | `c/src/serializers/` |
| C# | `c-sharp/src/GLD.SerializerBenchmark.csproj` (`dotnet build -c Release`) | `c-sharp/src/Serializers/` |
| C++ | `cpp/CMakeLists.txt` (`FetchContent`) | `cpp/src/serializers/` |
| Fortran | `fortran/fpm.toml` (`fpm build --profile release`) | `fortran/src/ser_*.f90` |
| Go | `go/go.mod` (`go get` / `go build`) | `go/serializers/` |
| Java | `java/pom.xml` (`mvn -q -DskipTests package`) | `java/src/main/java/benchmark/serializers/` |
| JavaScript | `javascript/package.json` (`npm install`) | `javascript/src/serializers/` |
| Kotlin | `kotlin/build.gradle.kts` (`./gradlew shadowJar`) | `kotlin/src/main/kotlin/benchmark/serializers/` |
| Mojo | `mojo/pixi.toml` (`pixi install`) | `mojo/src/bench/` |
| PHP | `php/composer.json` (`composer install`) | `php/src/Serializers/` |
| Python | `python/pyproject.toml` (`uv sync`) | `python/src/benchmark/serializers/` |
| Rust | `rust/Cargo.toml` (`cargo build --release`) | `rust/src/serializers/` |
| Swift | `swift/Package.swift` (`swift build -c release`) | `swift/Sources/SerializerBenchmarkCore/Serializers/` |
| Zig | `zig/build.zig.zon` (`zig build`) | `zig/src/` |

### 2. Implement Adapter, Register, and Wire Version Metadata

1. Implement the language's serializer interface using a stable `SerializerName` (do not rename existing keys without a migration).
2. Add domain attributes or generated IDL bindings only if required by the library; implement `Supports(type_id)` for unsupported shapes rather than logging errors on every cell.
3. Register the serializer in the language's registry (e.g., `c-sharp/src/Program.cs`, `python/src/benchmark/runner.py`, `rust/src/serializers/mod.rs`) and verify `SerializerVersion` populates cleanly (e.g., `c-sharp/src/SerializerVersionRegistry.cs`, `CARGO_PKG_VERSION`, `importlib.metadata`).
4. If the library requires a newer compiler or source generator (e.g., .NET 10 SDK for Roslyn 4.14+), update `<lang>/README.md`, `scripts/install-host-requirements.sh`, `scripts/check-host-requirements.sh`, and `.github/workflows/benchmark-ci.yml`.

### 3. Update Metadata Catalog and Documentation

1. Add a row to the `## Registered Serializers` table in `docs/<lang>/index.md` (`Serializer`, `Standard`, `Data sets`, `Stream I/O`, `Timed call path & notes`) and document any non-obvious caveat under `## Measurement Caveats`.
2. Add the library's origin text and repository URL override (if needed) to **`config/serializer-specifics.json`** (`url_override`, `spec_key`, `specifics`, `extra`) and register its standard mapping in the compliance catalog if applicable.
3. Regenerate catalog files and language provenance blocks:
   ```bash
   python3 dashboard/scripts/write-serializer-sources.py
   python3 scripts/apply-serializer-sources-to-docs.py
   ```
4. Verify documentation consistency:
   ```bash
   python3 scripts/check-docs.py
   ```

### 4. Peer-Smoke Audit, Full Run, and Dashboard Sync

Run a targeted smoke check against a peer on the **same standard** before executing the full matrix:

```bash
# Example (C#): 30 reps on message for quick size & throughput sanity check
cd c-sharp && ./scripts/run-benchmarks.sh custom 30 YourSerializerName message

# Full benchmark + analysis + compliance for the changed language only
cd ..
./scripts/run-all-benchmarks.sh --mode full --lang csharp --analyze
./scripts/run-compliance.sh --lang csharp
python3 dashboard/scripts/sync-data.py
```

### Reviewer Sanity Checks

| Signal | Expected | Action if Violated |
|---|---|---|
| Wire size vs. same-standard peer | Comparable order of magnitude | Audit framing / batching (`DataTypeInstanceCount`) |
| Batch scaling `size(n=100) / size(n=1)` | Roughly $50$–$150\times$ for binary codecs | Fix scalar-only encoding on batch cells |
| Throughput vs. similar-architecture peer | Within a few $\times$ after hot-path audit | Re-check encoder/buffer reuse and typed API binding before publishing |
| `FidelityScore` & `*.errors.csv` | `1.0` with no unexpected error rows | Fix round-trip semantics before publishing |
| `SerializerVersion` | Non-empty installed version | Wire runtime version resolver |

Do not commit gitignored raw logs under `logs/` or regenerate unrelated languages' Dashboard archives.

## Worked Example: C# Adapter Skeleton

Files touched for a typical .NET codec: `c-sharp/src/GLD.SerializerBenchmark.csproj`, `c-sharp/src/Serializers/YourLibSerializer.cs`, `c-sharp/src/Program.cs`, `c-sharp/src/SerializerVersionRegistry.cs`, `docs/c-sharp/index.md`, and `config/serializer-specifics.json`.

```csharp
namespace GLD.SerializerBenchmark.Serializers
{
    internal class YourLibSerializer : SerDeser
    {
        public override string Name => "YourLib"; // CSV SerializerName; matches SerializerVersionRegistry

        public override void Initialize(Type primaryType) { /* untimed schema/delegate setup */ }
        public override byte[] SerializeBytes(object serializable) { /* timed encode */ }
        public override object DeserializeBytes(byte[] serialized) { /* timed decode */ }
        public override void Serialize(object serializable, Stream outputStream) { /* timed stream write */ }
        public override object Deserialize(Stream inputStream) { /* timed stream read */ }
    }
}
```
