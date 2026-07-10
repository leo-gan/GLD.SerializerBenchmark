# Package docs lookup map

Use this when researching a suspect serializer. Prefer **official** README + **code examples**.

## How to research (required)

1. Identify package name from harness (CSV `SerializerName` / `SerializerVersion` / csproj / Cargo.toml / go.mod / package.json / CMake).
2. Open official docs (README / tutorial / API reference).
3. Copy the **recommended** serialize/deserialize example into notes.
4. Open harness client and compare call-for-call.
5. Only then edit.

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

## Harness client roots (monorepo)

| Lang | Client roots |
|------|----------------|
| csharp | `c-sharp/src/Serializers/`, maps: `c-sharp/src/TestData/V2/Maps/` |
| python | `python/src/benchmark/serializers/` |
| rust | `rust/src/serializers/` |
| go | `go/serializers/` |
| javascript | `javascript/src/serializers/` |
| c | `c/src/serializers/`, runners `c/src/run_v2.c`, `c/src/batch_cell.c` |

## Isolation reminder (C#)

Wrappers under `Serializers/` must not `using` suite domain models. Domain↔native lives in `TestData/V2/Maps/`.
