# Compliance

Serializer quality has two public questions:

| Question | Command |
|----------|---------|
| How fast / how big? | `./scripts/run-all-benchmarks.sh` |
| Does it match the cited spec section? | `./scripts/run-compliance.sh` |

This tab explains the catalog. **Live pass/fail numbers live only on the
[Dashboard → Compliance](../dashboard/#compliance)** view — the same rule
as timings (Dashboard, not these pages).

| You want… | Go here |
|-----------|---------|
| How to read a FAIL line | [Reading failures](reading-results.md) |
| JSON RFC 4627 / 7159 / 8259 and I-JSON | [JSON](json.md) |
| YAML 1.1 / 1.2 / 1.2.2 | [YAML](yaml.md) |
| TOML 0.5 / 1.0 / 1.1 | [TOML](toml.md) |
| CBOR RFC 7049 / 8949 | [CBOR](cbor.md) |
| MessagePack 2008 / 2013 / 2017 | [MessagePack](msgpack.md) |
| Protocol Buffers / Avro / BSON / FlatBuffers | [Protocol Buffers](protobuf.md), [Avro](avro.md), [BSON](bson.md), [FlatBuffers](flatbuffers.md) |
| Amazon Ion 1.0 / 1.1 | [Amazon Ion](ion.md) |
| UBJSON Draft 8 / 9 / 12 | [UBJSON](ubjson.md) |
| Smile 1.0 / shared / 1.0.4 | [Smile](smile.md) |
| Thrift, Cap’n Proto, Bond, Bebop, HOCON, plist, ZON | catalogs under `compliance/data/` |
| Plug in another language | [Language adapters](adapters.md) |
| Why we did not vendor suite X | [Legal provenance](legal.md) |

## What is in scope

First delivery: **self-describing text formats** and **IETF / industry
binary cousins** that this suite already benches.

| Format | Versions in the corpus | Typical Python serializers |
|--------|------------------------|-------------------------|
| JSON | RFC 4627, RFC 7159, RFC 8259, plus I-JSON (RFC 7493) | `json`, `orjson`, `msgspec`, `rapidjson` |
| YAML | 1.1, 1.2, 1.2.2 | PyYAML `safe_load` |
| TOML | 0.5.0, 1.0.0, 1.1.0 | `tomllib` (1.0) |
| CBOR | RFC 7049, RFC 8949 | `cbor2` |
| MessagePack | pre-2013 raw, 2013 str/bin/ext, 2017 timestamp | `msgpack`, `msgspec-msgpack` |
| Protocol Buffers | proto2, proto3, proto3 JSON | `protobuf` (every language runner now has a Doc adapter) |
| Avro | 1.8, 1.11, 1.12 | `fastavro` |
| BSON | 1.0, 1.1, 1.1 decimal128 | `bson` / pymongo |
| FlatBuffers | FlexBuffers, tables, file-id | `flexbuffers` |
| Amazon Ion | 1.0 text, 1.0 binary, 1.1 | `amazon-ion` |
| UBJSON | Draft 8, Draft 9, Draft 12 | `py-ubjson` |
| Smile | 1.0, 1.0 shared names, 1.0.4 | `newsmile` |
| Thrift | binary, compact | (catalog; Python adapter not wired) |
| Cap’n Proto | encoding, packed | (catalog; needs generated code) |
| Bond | compact, fast | (catalog) |
| Bebop | 1 | JS `bebop` (limited) |
| HOCON | 1 | (catalog) |
| Apple plist | XML, binary | `plistlib` |
| ZON | 1 | (catalog) |

XML is out of scope (user request). Language-native and private
binaries (pickle, gob, Kryo, …) are on the Dashboard under
**Standard → No public spec**: one column, no pass/fail cells, so they
stay selectable as a group.

## How a case is written

Every case is a JSON object with:

- a stable `id`
- `expect`: `accept` or `reject`
- `requirement`: `MUST` / `MUST NOT` / `SHOULD` / …
- `section_url` pointing at the published paragraph
- `paragraph`: the rule in one or two sentences
- `input`: text or hex
- optional `decoded`: the value we compare if the parse must succeed

Cases are **original**. They use names like `harbor` / `kelp` / `berth`,
not the examples from the spec PDF. See [legal provenance](legal.md).

Official MIT/BSD suites are vendored (JSONTestSuite, yaml-test-suite,
toml-test, msgpack-test-suite, cbor-wg vectors) plus original extras.
A compliance **case** is not a suite **data type**. Data types stay
`message`, `document`, `telemetry`, `strings`, and `event` — the
benchmark sample shapes. See [Test data](../analysis/test_data_configuration.md).

## How to run

From the repository root (Python 3.12+ and [uv](https://docs.astral.sh/uv/)):

```bash
./scripts/run-compliance.sh
./scripts/run-compliance.sh --format json --serializer orjson
./scripts/run-compliance.sh --detailed
```

The report lands in `logs/compliance/YYYY-MM-DD-HHMMSS.json`. A full
(unfiltered) run also updates `dashboard/public/data/compliance.json`
for the [Dashboard Compliance](../dashboard/#compliance) view.

`./scripts/run-compliance.sh` also runs every other language toolchain
it finds. Each writes `logs/compliance/latest-<lang>.json`. The
Dashboard merges them.

This is a **local quality command**, not a CI job and not part of `pytest`.

## Policy: report-only

The command **does not fail** because a library disagrees with a MUST.
Production parsers often accept RFC-invalid input on purpose (NaN,
YAML 1.1 `yes`, TOML 1.1 syntax on a 1.0 decoder).

The run **does** fail (exit 2) if a catalog file is missing, malformed,
or lacks a spec URL — that is a runner bug.

A FAIL prints a block like this:

```text
COMPLIANCE MUST NOT FAIL [json-8259-bare-nan] json
  Standard : RFC 8259 8259
  Section  : 6 — Numbers
  Spec     : https://www.rfc-editor.org/rfc/rfc8259#section-6
  Rule     : Numeric values are produced from the number grammar; NaN is not a number token.
  Expected : reject
  Observed : accepted as nan
  Case     : NaN is not a JSON number
```

The `Spec` line is the document you should open.

## Layout in the repo

```text
compliance/data/<format>/<version>.json   # catalog (no network)
compliance/LEGAL.md                       # license audit
scripts/run-compliance.sh                 # public command
python/src/compliance/                    # runner + adapters
docs/compliance/                          # this tab
```

There is no git submodule and no download at run time.
