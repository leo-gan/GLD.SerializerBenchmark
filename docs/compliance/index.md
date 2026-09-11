# Compliance

Serializer quality has two public questions:

| Question | Command |
|----------|---------|
| How fast / how big? | [`./scripts/run-all-benchmarks.sh`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/scripts/run-all-benchmarks.sh) |
| Does it match the cited spec section? | [`./scripts/run-compliance.sh`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/scripts/run-compliance.sh) |

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

Protobuf, Avro, BSON, XML, and UBJSON are documented as *researched,
not shipped* on the [legal](legal.md) page (license or scope).

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
for the [Dashboard Compliance](../dashboard/#compliance) view. This is
a **local quality command**, not a CI job and not part of `pytest`.

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
