# Compliance

Serializer quality has two public questions:

| Question | Command |
|----------|---------|
| How fast / how big? | `./scripts/run-all-benchmarks.sh` |
| Does it match the cited spec section? | `./scripts/run-compliance.sh` |

This tab explains the catalog. Live pass/fail numbers are on the
[Dashboard → Compliance](../dashboard/#compliance) view, the same place as
the timings. A language and serializer deep-link is
`#compliance/{lang}/{serializer}` (example:
[Python orjson](../dashboard/#compliance/python/orjson)).

## What is in scope

The catalog covers every standard in this table.

| Format | Versions in the corpus | Typical Python serializers |
|--------|------------------------|-------------------------|
| ADIOS2 | BP5 | `adios2` |
| Amazon Ion | 1.0 text, 1.0 binary, 1.1 | `amazon-ion` |
| Arrow IPC | IPC stream | `arrow-ipc` |
| Avro | 1.8, 1.11, 1.12 | `fastavro` |
| Bebop | 1 | JS `bebop` (limited) |
| Bond | compact, fast | (catalog) |
| BSON | 1.0, 1.1, 1.1 decimal128 | `bson` / pymongo |
| Cap'n Proto | encoding, packed | (catalog; needs generated code) |
| CBOR | RFC 7049, RFC 8949 | `cbor2` |
| FlatBuffers | FlexBuffers, tables, file-id | `flexbuffers` |
| HDF5 | superblock 0, superblock 2 | `h5py` |
| HOCON | 1 | (catalog) |
| JSON | RFC 4627, RFC 7159, RFC 8259, plus I-JSON (RFC 7493) | `json`, `orjson`, `msgspec`, `rapidjson` |
| Kiln | wire v2 | (no Python adapter; Mojo `gld-kiln`) |
| MessagePack | pre-2013 raw, 2013 str/bin/ext, 2017 timestamp | `msgpack`, `msgspec-msgpack` |
| NetCDF | classic, 64-bit offset, NetCDF-4 | `netCDF4` |
| ORC | v1 | `orc`, `orc-uncompressed` |
| Parquet | file format | `parquet`, `parquet-uncompressed` |
| Property List | XML, binary | `plistlib` |
| Protocol Buffers | proto2, proto3, proto3 JSON | `protobuf` (every language runner now has a Doc adapter) |
| SBE | 1.0 | `sbe` |
| Smile | 1.0, 1.0 shared names, 1.0.4 | `newsmile` |
| Thrift | binary, compact | (catalog; Python adapter not wired) |
| TOML | 0.5.0, 1.0.0, 1.1.0 | `tomllib` (1.0) |
| UBJSON | Draft 8, Draft 9, Draft 12 | `py-ubjson` |
| YAML | 1.1, 1.2, 1.2.2 | PyYAML `safe_load` |
| ZON | 1 | (catalog) |

Arrow IPC, Parquet, ORC v1, and SBE 1.0 have validity cases under `compliance/data/`. Each cell is that library’s own reader. Accept means the reader decoded the case, and when the case names a value the decoded rows must match. A library that accepts a reject case fails that case. Python has no SBE row. Score each of these rows with that library’s own decoder.

HDF5, NetCDF, and ADIOS2 use small original corpora. HDF5 checks the file signature and the superblock version. NetCDF checks a classic header, a 64-bit-offset header, and a NetCDF-4 header. ADIOS2 checks the BP5 index file names. Kiln wire v2 checks the version-2 tensor directory. `gld-kiln` is the only Kiln adapter.

XML is out of scope. Language-native and private binaries (pickle, gob, Kryo, and the rest) are on the Dashboard under **Standard → No public spec**: one column, no pass/fail cells, so they stay selectable as a group.

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
A compliance **case** is not a suite **data type**. The data types are
`message`, `document`, `telemetry`, `strings`, `event`, `table`,
`table_project`, `nested_table`, `signal`, `graph`, `grid`, and
`grid_window`. See [Terminology](../analysis/terminology.md) and
[Test data](../analysis/test_data_configuration.md).

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
or lacks a spec URL. That is a runner bug.

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
