# Adding a serializer

Checklist for **library authors and contributors** who want to add one codec to an
**existing** language tree. You do **not** need to add a language for this.

Adding a whole language: [Adding a language](ADDING_A_LANGUAGE.md).  
Background: [Architecture](architecture.md) · [Modes](modes.md) · [Metrics](METRICS.md).

---

## Learning goals

After this page you should be able to:

1. Wire a library into one language’s benchmark runner so it appears in the CSV.
2. Fill `SerializerVersion`, inventory docs, and counts correctly.
3. Run a smoke/full bench, regenerate published results, and open a PR that reviewers can merge.

---

## Before you start

| Question | Why it matters |
|----------|----------------|
| Which **language** tree? (`c-sharp/`, `python/`, …) | Each tree has its own interface and registration list |
| Can the library serialize the **suite domain types**? | Prefer the library’s normal path on domain POCOs; use untimed maps only when the codec needs a native shape |
| Source generators / AOT / special toolchain? | Document host SDK requirements (example: LightProto needs **.NET SDK 9+** for its generator while the project still targets net8.0) |
| Default configuration only? | The suite measures **library defaults**, not hand-tuned production settings |

Pick an existing sibling under `<lang>/…/Serializers/` (or equivalent) and copy its structure.

---

## Shared rules (all languages)

These keep rankings comparable. Violating them produces “suspicious” numbers even when the library is fine.

### Timing honesty

| Do | Don’t |
|----|--------|
| Time **serialize** and **deserialize** only | Time schema compile, codegen, type registration, domain↔native maps, or buffer setup |
| Put setup in **prepare / Initialize / PrepareData** (untimed) | Allocate a brand-new encoder every call when the library documents reuse |
| Use real library stream APIs for **stream** mode when they exist | Make stream a free alias of the string/bytes path without documenting it as adapted |
| Encode **N instances** when the cell says `DataTypeInstanceCount=N` | Label N but serialize one object |

### Isolation

- Wrapper code should **not** hard-code suite type names (`Message`, `Telemetry`, …) when the runner can pass `Type` / generics / maps.
- Library-specific contracts (generated protobuf messages, FlatBuffer tables, CSV row DTOs) are fine in dedicated folders.

### Correctness

- Round-trip must pass the suite **fidelity** check (`FidelityScore` ≈ 1.0).
- Failures go to `logs/<lang>/<ts>.errors.csv` (only when there are errors).
- Prefer native wire formats over “JSON stuffed into another codec” envelopes. If an envelope is unavoidable, document it on the language inventory page (see C# envelope codecs).

### Version column

CSV column **`SerializerVersion`** (immediately after `SerializerName`) must show the **installed** package/crate/module version at runtime — not a hard-coded string in most cases.

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
| C / C++ / Swift | language README (system or vendored deps) |

Pin a sensible range (for example NuGet `1.*`, cargo compatible versions). Prefer the latest stable major the suite already uses for peers.

### 2. Wrapper

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

**Name property:** stable display string used as CSV `SerializerName` (for example `LightProto`, `ProtoBuf`). Do not change existing names without a docs migration.

**Prepare path:** override prepare/Initialize when you need one-time compile, maps, or cached readers/writers.

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

### 8. Build, smoke, then full results

From the repo root (toolchains via `./scripts/install-host-requirements.sh <lang>` if needed):

```bash
# Smoke: your serializer only, one data type (example: C#)
cd c-sharp && ./scripts/run-benchmarks.sh custom 5 YourSerializerName message

# Or full matrix for the language (preferred before merge)
cd ..
./scripts/run-all-benchmarks.sh --mode full --lang csharp --analyze
```

Confirm:

- CSV has rows for your `SerializerName` with non-empty `SerializerVersion`.
- `FidelityScore` is `1.00` (or document known limitations).
- No new unexpected rows in `*.errors.csv`.
- `docs/<lang>/results.md` and violin plots updated when you ran `--analyze`.
- Optional dashboard: `python3 dashboard/scripts/sync-data.py` (commit `dashboard/public/data/<lang>_latest.json.gz` if you publish dashboard data).

### 9. Pull request

| Include | Avoid |
|---------|--------|
| Wrapper + registration + dependency | Untuned “it compiles” without a smoke CSV |
| Version map / version getter | Blank `SerializerVersion` |
| Docs inventory + count bumps | Regenerating unrelated languages’ results |
| Full (or at least all-single) run for **that** language | Force-adding gitignored raw `logs/**` CSVs unless the project asks for them |
| Short PR notes: library link, any honesty caveats, SDK needs | Scope creep into analysis core |

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

        public override string Serialize(object serializable) { /* … */ }
        public override object Deserialize(string serialized) { /* … */ }
        public override void Serialize(object serializable, Stream outputStream) { /* … */ }
        public override object Deserialize(Stream inputStream) { /* … */ }
    }
}
```

`SerDeser.Version` already calls `SerializerVersionRegistry.Resolve(Name)`. You only add the map entry unless you override `Version`.

**Binary on string mode:** return Base64 of the byte payload (same as ProtoBuf / MemoryPack) so the column stays a `string` while size still reflects wire length after decode in analysis conventions used by peers.

**Verify version locally:**

```bash
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
cd c-sharp
./scripts/run-benchmarks.sh custom 2 YourLib message
# inspect logs/csharp/<latest>.csv → SerializerVersion column
```

---

## Sanity checks reviewers will look for

| Signal | Healthy | Suspicious |
|--------|---------|------------|
| Size vs peer same family | Same order of magnitude (e.g. protobuf peers agree) | Size 0/1 with fidelity 1.0 |
| `size(n=100)/size(n=1)` | Roughly ~50–150 for real batches | Ratio ≈ 1 (LABEL≠WORK) |
| Fidelity | 1.0 | Failures or skipped checks |
| Version | Semver / package version | Empty |
| Stream vs string (binary) | String size ≈ 4/3 stream if Base64 | Identical size and identical code path without docs |

Deeper audit process: maintainers may run the repo’s **review-suspicious-results** skill (outlier scan + package-docs check).

---

## Related pages

- [Adding a language](ADDING_A_LANGUAGE.md) — new runtime tree, not one codec
- [Architecture](architecture.md) — timing model and folder layout
- [Modes](modes.md) — bytes/string vs stream
- [Test data](test_data_configuration.md) — suite type ids and batch cells
- [Metrics](METRICS.md) — CSV columns including `SerializerVersion`
