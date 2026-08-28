# Adding a serializer

Checklist for **library authors and contributors** who want to add one codec to an
**existing** language tree. You do **not** need to add a language for this.

Adding a whole language: [Adding a language](ADDING_A_LANGUAGE.md).  
Background: [Architecture](architecture.md) · [Modes](modes.md) · [Metrics](METRICS.md).

---

## Learning goals

After this page you should be able to:

1. Wire a library into one language’s benchmark runner so it appears in the CSV.
2. Land a **performance-complete** client (documented hot path, not only a correct round-trip).
3. Fill `SerializerVersion`, inventory docs, and counts correctly.
4. Run a smoke/full bench, regenerate published results, and open a PR that reviewers can merge.

---

## Before you start

| Question | Why it matters |
|----------|----------------|
| Which **language** tree? (`c-sharp/`, `python/`, …) | Each tree has its own interface and registration list |
| Can the library serialize the **suite domain types**? | Prefer the library’s normal path on domain POCOs; use untimed maps only when the codec needs a native shape |
| What is the library’s **recommended** ser/de entry point? | README “Getting started” snippets are often *minimal*, not *optimal* for a tight loop |
| Source generators / AOT / special toolchain? | Document host SDK requirements (example: LightProto needs **.NET SDK 9+** for its generator while the project still targets net8.0) |
| Default configuration only? | The suite measures **library defaults**, not hand-tuned production settings |

Pick an existing sibling under `<lang>/…/Serializers/` (or equivalent) and copy its structure.

---

## Shared rules (all languages)

These keep rankings comparable. Violating them produces “suspicious” numbers even when the library is fine. The full contract is **[Timing honesty](TIMING_HONESTY.md)**.

### Timing honesty

| Do | Don’t |
|----|--------|
| Time **serialize** and **deserialize** only | Time schema compile, codegen, type registration, domain↔native maps, or buffer setup |
| Put setup in **prepare / Initialize / PrepareData** (untimed) | Write the **output bytes** in `prepare` and copy them in `serialize`, or allocate a new encoder every call when the library documents reuse |
| Reuse readers/writers/encoders/decoders when the API allows | Copy a “new X every call” snippet from Getting Started into the timed loop without checking reuse |
| Use real library stream APIs for **stream** mode when they exist; emit `StreamMode=native` or `text_on_stream` | Make stream a free alias of the string/bytes path, or label `native` while still using bytes APIs |
| Encode **N instances** when the cell says `DataTypeInstanceCount=N` | Label N but serialize one object |

### Isolation

- Wrapper code should **not** hard-code suite type names (`Message`, `Telemetry`, …) when the runner can pass `Type` / generics / maps.
- Library-specific contracts (generated protobuf messages, FlatBuffer tables, CSV row DTOs) are fine in dedicated folders.
- Isolation does **not** force a slow path: bind typed APIs from a runtime `Type` (e.g. `MakeGenericType` + compiled delegates) when that matches the library’s fast entry points.

### Correctness

- Round-trip must pass the suite **fidelity** check (`FidelityScore` ≈ 1.0).
- Failures go to `logs/<lang>/<ts>.errors.csv` (only when there are errors).
- Prefer native wire formats over “JSON stuffed into another codec” envelopes. If an envelope is unavoidable, document it on the language inventory page (see C# envelope codecs).

### Version column

CSV column **`SerializerVersion`** (immediately after `SerializerName`) must show the **installed** package/crate/module version at runtime — not a hard-coded string in most cases.

### Hot path before full matrix (required) {#hot-path-before-full-matrix-required}

A PR that only “compiles and round-trips” is incomplete for this suite. **Correctness and the documented hot path land in the same first PR** — do not wait for a later “performance pass” after published numbers look slow.

#### 1. Read package docs *and* examples for the tight loop

For the language/ecosystem of the library, open at least one of:

- Official README / tutorial / “Getting started”
- API reference (docs.rs, nuget.org, pkg.go.dev, …)
- Upstream **examples** or perf samples that show serialize/deserialize in a loop

Record the entry points you will call (e.g. `ReflectWriter<T>.Write`, `write_avro_datum_ref`, `Marshal`).

Getting-started samples often allocate a new encoder/decoder per call for clarity. That is fine for demos; **it is usually wrong for the timed path** if the library can reuse instances.

#### 2. Prefer the library’s recommended high-throughput path

| Prefer | Avoid on the timed path (unless docs force it) |
|--------|--------------------------------------------------|
| Typed / generic writers bound once (`Writer<T>`, frozen API, monomorphic fn) | Unrelated “default object” APIs that re-resolve types every call |
| Schema / `ClassCache` / `RuntimeTypeModel` / codec config built **once** in prepare | Rebuild schema or reflection metadata every serialize |
| Reused buffers and encoders when the type holds only a `Stream` / slice | `new BinaryEncoder(stream)` every rep when a long-lived encoder works |
| `Read(reuse, …)` / decode-into when the library supports it | Always allocate a fresh root object when reuse is safe and documented |
| Single-pass ser/de to the domain or native type | Extra intermediate graphs when docs offer a direct path (e.g. avoid an unneeded `Value` round-trip on **serialize** if a direct writer exists) |

If the only public API is inherently two-step (example: some Avro crates decode to a generic value then `from_value`), document that in the inventory as **expected** library behavior — after you confirm there is no faster public API.

#### 3. Microbench or peer-smoke before the full language matrix

Before `full` / publishing Dashboard data:

```bash
# Example: C# — your codec only, message, enough reps to ignore warmup
cd c-sharp && ./scripts/run-benchmarks.sh custom 30 YourSerializerName message
```

Then compare **order of magnitude** against an existing peer in the **same family** (e.g. other schema codecs: protobuf / Bond / FlatBuffers peers — not MemoryPack vs YAML).

| Signal | Action |
|--------|--------|
| Size matches family peers; ops within ~2–3× of a peer of similar design | Good enough to proceed to full |
| Size wrong (0/1, or ≪ peers) | Fix harness / batch framing first (LABEL≠WORK) |
| Size OK but ops ≪ peers by ~5–10× | Re-check docs for reuse, typed API, prepare placement — **do not publish full numbers yet** |
| Still slow after hot-path audit | Document as expected library cost; cite docs |

A **30-second local microbench** of “snippet path” vs “reuse path” (same payload, N ≥ 10⁵ in a tiny console app) is often enough to catch multi-× mistakes before any suite full run.

#### 4. Case study: Apache.Avro on C# (what went wrong)

First landing used `ReflectDefaultWriter` + `Read<object>` + **new** `BinaryEncoder`/`BinaryDecoder` every call. Round-trips and sizes matched Java/Go Avro, but **message@n=1 Stream** was ~4× slower than necessary.

Official [Reflect README](https://avro.apache.org/docs/1.12.0/api/csharp/html/md_src_apache_main_Reflect_README.html) shows `ReflectWriter<T>` / `ReflectReader<T>` and a shared `ClassCache`. Local microbench then showed:

- Typed writer + **reused** encoder ≫ default writer + new encoder each call  
- Typed reader + **reused** decoder + **reuse object** on `Read` ≫ `Read(null, new BinaryDecoder(…))` every call  

Isolation was preserved by binding `ReflectWriter<>` / `ReflectReader<>` from the runtime primary `Type` in `Initialize` (compiled delegates), not by hard-coding suite type names.

**Lesson:** “Works like the docs sample” ≠ “optimal for a microbenchmark harness.” Do the hot-path pass **before** full-matrix results.

---

## Checklist (every language)

Use this as a PR self-review list.

### 1. Dependency

Add the library to the language package manifest and restore/build once:

| Language | Manifest / restore |
|----------|-------------------|
| C# | `c-sharp/src/GLD.SerializerBenchmark.csproj` → `dotnet restore` / `dotnet build` |
| Python | `python/pyproject.toml` → `uv sync` |
| Rust | `rust/Cargo.toml` → `cargo build --release` |
| Go | `go/go.mod` → `go get` / `go build` |
| JavaScript | `javascript/package.json` → `npm install` |
| Java | `java/pom.xml` → `mvn -q -DskipTests package` |
| Kotlin | `kotlin/build.gradle.kts` → `./gradlew shadowJar` |
| PHP | `php/composer.json` → `composer install` |
| C / C++ / Swift | language README (system or vendored deps) |

Pin a sensible range (for example NuGet `1.*`, cargo compatible versions). Prefer the latest stable major the suite already uses for peers.

### 2. Wrapper (correct **and** hot-path complete)

Implement the language’s serializer interface (name + ser/deser for **bytes/string** and **stream**).

Typical locations:

| Language | Wrapper directory | Interface / base |
|----------|-------------------|------------------|
| C# | `c-sharp/src/Serializers/` | `ISerDeser` / `SerDeser` |
| Python | `python/src/benchmark/serializers/` | `Serializer` protocol |
| Rust | `rust/src/serializers/` | suite trait + registry |
| Go | `go/serializers/` | suite interface |
| JavaScript | `javascript/src/serializers/` | suite interface |
| Java | `java/src/main/java/benchmark/serializers/` | suite interface |
| Kotlin | `kotlin/src/main/kotlin/benchmark/serializers/` | suite interface |
| PHP | `php/src/Serializers/` | suite interface |

**Name property:** stable display string used as CSV `SerializerName` (for example `LightProto`, `ProtoBuf`). Do not change existing names without a docs migration.

**Prepare path:** override prepare/Initialize when you need one-time compile, maps, or cached readers/writers.

**Hot path (same PR as the wrapper):** apply [Hot path before full matrix](#hot-path-before-full-matrix-required). Do not ship a “v1 correct, v2 fast later” client for this suite.

### 3. Register in the runner

Add an instance to the language’s “all serializers” list so smoke/full runs include it.

| Language | Registration |
|----------|----------------|
| C# | `c-sharp/src/Program.cs` (`allSerializers`) |
| Python | `ALL_SERIALIZERS` in the package entry / `runner_v2` |
| Others | See that language’s README **How to Extend** section |

### 4. Version reporting

Ensure `SerializerVersion` is non-empty in the CSV.

| Language | How |
|----------|-----|
| **C#** | Map `Name` → assembly simple name in `c-sharp/src/SerializerVersionRegistry.cs` (default `SerDeser.Version` reads this). Assembly name is usually the NuGet package id (for example `LightProto` → `"LightProto"`). |
| Python | Return installed distribution version from the wrapper (see existing serializers). |
| Rust | Crate version from `CARGO_PKG_VERSION` or equivalent already used by peers. |
| Others | Mirror an existing peer in the same tree. |

**Smoke check:** after a short run, open the CSV and confirm your row shows a real version (for example `1.3.4`), not blank.

### 5. Domain model / attributes / maps (only if needed)

- **Attribute-driven codecs** (protobuf-net, LightProto, MemoryPack, Bond, …): mark suite domain types under the language’s models folder (C#: `c-sharp/src/TestData/V2/Models.cs`). Keep member orders/tags aligned with the suite catalog when the wire format is schema-like.
- **IDL / codegen codecs** (official protobuf, FlatBuffers, Avro, …): keep generated types separate; convert domain ↔ native in **untimed** `PrepareData` / `ToDomain` (see existing FlatSharp / Google.Protobuf clients).
- **Unsupported shapes:** implement `Supports(testDataName)` (or equivalent) and skip cleanly rather than erroring every cell.

### 6. Toolchain / source generators

If the library needs a **newer compiler or analyzer** than the suite’s default host:

1. Document it in the language README **Requirements**.
2. Update `scripts/install-host-requirements.sh` and `scripts/check-host-requirements.sh` if install/check should enforce it.
3. Update CI (`.github/workflows/benchmark-ci.yml`) so smoke jobs use a compatible SDK.

Example lesson from LightProto: the package builds on .NET 8 targeting packs, but its **source generator requires Roslyn 4.14+ (.NET SDK 9+)**. With SDK 8 alone the project compiles, parsers are never generated, and every cell fails with `No ProtoParser registered…`.

### 7. Inventory and counts

Update human-facing inventory so the site matches the runner:

1. Language overview table — for example `docs/c-sharp/index.md` (log name, category, one-line notes).
2. Language README serializer count (if it states a number).
3. Root `README.md` language bullet count (if present).
4. Comment in `config/benchmark_config.yaml` for that language (if it mentions a count).
5. Stream/string honesty notes if the path is adapted or Base64-on-string (binary codecs on C# string mode usually Base64).
6. Optional one-line **call-path** note when the library has a known slow public API (e.g. Reflect vs codegen, two-step Avro deser).

### 8. Build, peer-smoke, then full results

From the repo root (toolchains via `./scripts/install-host-requirements.sh <lang>` if needed):

```bash
# Peer-smoke: your serializer only, enough reps to ignore warmup (example: C#)
cd c-sharp && ./scripts/run-benchmarks.sh custom 30 YourSerializerName message

# Spot-check size + ops vs a same-family peer already in the suite, then:

# Full matrix for the language (preferred before merge)
cd ..
./scripts/run-all-benchmarks.sh --mode full --lang csharp --analyze
```

Confirm:

- CSV has rows for your `SerializerName` with non-empty `SerializerVersion`.
- `FidelityScore` is `1.00` (or document known limitations).
- No new unexpected rows in `*.errors.csv`.
- **Ops/s (or total time) is not an unexplained multi-× outlier** vs same-family peers after the hot-path audit.
- `size(n=100)/size(n=1)` roughly scales with N for binary codecs.
- Dashboard Details / Compare: `python3 dashboard/scripts/sync-data.py` (commit `dashboard/public/data/<lang>_latest.json.gz` if you publish dashboard data).
- Unpublished report: `analyze-benchmarks` writes `reports/<docs_dir>/results.md` (do not commit to the site).

### 9. Pull request

| Include | Avoid |
|---------|--------|
| Wrapper + registration + dependency | Untuned “it compiles” without a smoke CSV |
| Hot-path client (reuse / typed API / prepare) | Publishing full numbers on a known multi-×-slow snippet path |
| Version map / version getter | Blank `SerializerVersion` |
| Docs inventory + count bumps | Regenerating unrelated languages’ results |
| Full (or at least all-single) run for **that** language | Force-adding gitignored raw `logs/**` CSVs unless the project asks for them |
| Short PR notes: library link, call-path notes, honesty caveats, SDK needs | Scope creep into analysis core |

Fork PRs may need a maintainer to **Approve and run workflows** before CI jobs start.

---

## C# walkthrough (most common contributor path)

Concrete files for .NET:

| Step | File / action |
|------|----------------|
| Package | `c-sharp/src/GLD.SerializerBenchmark.csproj` — `<PackageReference Include="YourLib" Version="…" />` |
| Wrapper | `c-sharp/src/Serializers/YourLibSerializer.cs` — subclass `SerDeser` |
| Register | `c-sharp/src/Program.cs` — `new YourLibSerializer()` in the list |
| Version | `c-sharp/src/SerializerVersionRegistry.cs` — `["YourLogName"] = "Assembly.Name"` |
| Domain attrs | `c-sharp/src/TestData/V2/Models.cs` — only if the library needs attributes on POCOs |
| Map / contracts | `Serializers/Contracts/`, `TestData/V2/Maps/` — only if native types differ |
| Inventory | `docs/c-sharp/index.md` + counts in `c-sharp/README.md`, root `README.md`, `config/benchmark_config.yaml` |
| Host SDK | `c-sharp/README.md` Requirements; install/check scripts + CI if generators need a newer SDK |

Minimal wrapper shape:

```csharp
namespace GLD.SerializerBenchmark.Serializers
{
    internal class YourLibSerializer : SerDeser
    {
        public override string Name => "YourLib"; // CSV SerializerName; must match version map key

        // Prefer: Initialize/PrepareData for one-time setup (schema, ClassCache, compiled model, …)

        public override string Serialize(object serializable) { /* … */ }
        public override object Deserialize(string serialized) { /* … */ }
        public override void Serialize(object serializable, Stream outputStream) { /* … */ }
        public override object Deserialize(Stream inputStream) { /* … */ }
    }
}
```

`SerDeser.Version` already calls `SerializerVersionRegistry.Resolve(Name)`. You only add the map entry unless you override `Version`.

**Binary on string mode:** return Base64 of the byte payload (same as ProtoBuf / MemoryPack) so the column stays a `string` while size still reflects wire length after decode in analysis conventions used by peers.

**C# hot-path habits (same PR):**

| Habit | Why |
|-------|-----|
| Build schema / `RuntimeTypeModel` / formatters in `Initialize` or `PrepareData` | Untimed setup |
| Prefer typed APIs (`Something<T>`) bound once from `Type` | Avoid re-resolving via `object` every call |
| Reuse `MemoryStream` + encoder/decoder on the **string/Base64** path when the library allows | Official samples often `new` every time; the timed path should not |
| Pass a **reuse** instance into deserialize when the API supports it | Cuts alloc on the hot loop |
| Stream path: real library write/read on the harness `Stream` | Do not invent a slow redirect layer unless measurements show it helps |

Reference client that went through this audit: `c-sharp/src/Serializers/ApacheAvroSerializerSer.cs` (typed Reflect + reuse on the string path).

**Verify version + peer-smoke locally:**

```bash
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
cd c-sharp
./scripts/run-benchmarks.sh custom 30 YourLib message
# inspect logs/csharp/<latest>.csv → SerializerVersion, FidelityScore, TimeSer/TimeDeser
# compare ops order-of-magnitude to an existing schema peer (e.g. Google.Protobuf, ProtoBuf)
```

---

## Sanity checks reviewers will look for

| Signal | Healthy | Suspicious |
|--------|---------|------------|
| Size vs peer same family | Same order of magnitude (e.g. protobuf / Avro peers agree) | Size 0/1 with fidelity 1.0 |
| `size(n=100)/size(n=1)` | Roughly ~50–150 for real batches | Ratio ≈ 1 (LABEL≠WORK) |
| Ops/s vs same-family peer | Within a few × of a similar design (after hot-path audit) | Multi-× slower with “new encoder every call” still in the wrapper |
| Fidelity | 1.0 | Failures or skipped checks |
| Version | Semver / package version | Empty |
| Stream vs string (binary) | String size ≈ 4/3 stream if Base64 | Identical size and identical code path without docs |
| Prepare vs timed | Schema/cache only in prepare | Schema parse or heavy reflection every rep |

Deeper audit process: maintainers may run the repo’s **review-suspicious-results** skill (outlier scan + package-docs check). That process should be a **safety net**, not the first time the hot path is considered — do the [hot-path section](#hot-path-before-full-matrix-required) yourself before opening the PR.

---

## Related pages

- [Adding a language](ADDING_A_LANGUAGE.md) — new runtime tree, not one codec
- [Architecture](architecture.md) — timing model and folder layout
- [Modes](modes.md) — bytes/string vs stream
- [Test data](test_data_configuration.md) — suite type ids and batch cells
- [Metrics](METRICS.md) — CSV columns including `SerializerVersion`
- [Serialization categories](serialization_categories.md) — compare within family when judging “too slow”
