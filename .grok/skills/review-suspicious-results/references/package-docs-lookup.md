# Package docs lookup map

Use this when researching a suspect serializer. Prefer **official** README + **code examples**.

## How to research (required)

1. Identify package name from harness (CSV `SerializerName` / `SerializerVersion` / csproj / Cargo.toml / go.mod / package.json / CMake).
2. Open official docs (README / tutorial / API reference).
3. Copy the **recommended** serialize/deserialize example into notes.
4. Open harness client and compare call-for-call.
5. Only then edit.

**If the signal is BATCH-AXIS or CROSS-LANGUAGE (whole language under-size at n=N):**  
skip steps 2–3 for individual crates first. Open the **runner / batch cell** paths below.
Package docs cannot prove the harness feeds N instances.

## Typical doc homes

| Ecosystem | Primary | Examples also on |
|-----------|---------|------------------|
| NuGet / C# | GitHub repo README, nuget.org | Microsoft Learn (only for BCL serializers) |
| PyPI | pypi.org project + linked docs | GitHub `README.md`, ReadTheDocs |
| crates.io | docs.rs/`crate` | GitHub README |
| Go | pkg.go.dev/`module` | GitHub README |
| npm | npmjs.com package page | GitHub README |
| C libs | Project site / GitHub / `third_party/*/README*` | Header comments |

## Anti-patterns to hunt after reading docs

- Extra JSON/base64 layer not in the official example
- New encoder/builder every call when docs say “reuse”
- Reflection in the hot path when docs show generic/static APIs
- Stream path = bytes path with only a label change
- Deserializing without the type/schema the docs require
- Measuring convert-to-native inside timed ser/deser (should be prepare)
- **Label N / `DataTypeInstanceCount=N` but only one object built or serialized**
- **Fidelity / size measured on a single item while the row claims a batch of N**

## Harness client roots (monorepo)

| Lang | Client roots | Runner / batch (LABEL≠WORK) |
|------|--------------|------------------------------|
| csharp | `c-sharp/src/Serializers/`, maps: `c-sharp/src/TestData/V2/Maps/` | run loop + config that sets instance count |
| python | `python/src/benchmark/serializers/` | suite runner / multi-instance fixture build |
| rust | `rust/src/serializers/` | **`rust/src/run_v2.rs`**, `rust/src/data_v2.rs` |
| go | `go/serializers/` | go runner fixture batch |
| javascript | `javascript/src/serializers/` | JS runner fixture array for N |
| java | `java/src/main/java/benchmark/serializers/` | Main work items / DataTypeInstanceCount |
| c | `c/src/serializers/` | **`c/src/run_v2.c`**, **`c/src/batch_cell.c`** |

Reference batch framing: C `batch_cell` (u32 count + per-item length + payload). Rust should match that contract when encoding N&gt;1.

## Isolation reminder (C#)

Wrappers under `Serializers/` must not `using` suite domain models. Domain↔native lives in `TestData/V2/Maps/`.

## Historical miss (Rust speedy @ n=100)

Within-Rust relative scan + Speedy docs both looked fine while `run_v2` labeled N=100 and encoded one fixture. Always run batch-axis + cross-lang checks; see SKILL.md “Lessons learned”.
