# Serialization compliance corpus

Static, dependency-free catalog for **JSON**, **YAML**, **TOML**, **CBOR**,
and **MessagePack**, with up to three industry versions of each standard.

This is the **spec-quality** counterpart to the speed benchmark.

| Question | Command |
|----------|---------|
| How fast / how big? | `./scripts/run-all-benchmarks.sh` |
| Does it match the cited spec section? | `./scripts/run-compliance.sh` |

| You want… | Go here |
|-----------|---------|
| Human docs (site tab **Compliance**) | [`docs/compliance/`](../docs/compliance/index.md) |
| Legal / license audit | [`LEGAL.md`](LEGAL.md) |
| IETF Appendix A notice | [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) |
| Catalog JSON | [`data/`](data/) |
| Python runner | [`python/src/compliance/`](../python/src/compliance/) |

## Run (public API)

From the repo root. Requires Python 3.12+ and [uv](https://docs.astral.sh/uv/).

```bash
./scripts/run-compliance.sh
./scripts/run-compliance.sh --format json --adapter orjson
./scripts/run-compliance.sh --detailed
```

The report is written to `logs/compliance/YYYY-MM-DD-HHMMSS.json`.
Library deviations print a block with the RFC/spec URL. They do **not**
fail the process (exit `0`). Exit `2` only if the catalog cannot be loaded.

This is **not** a pytest or CI job. `pytest` still covers the Python
benchmark runner; it does not run the compliance catalog.

## Catalog shape

Each `data/<format>/<version>.json` file is one standard version:

```json
{
  "format": "json",
  "standard": "RFC 8259",
  "version": "8259",
  "standard_url": "https://www.rfc-editor.org/rfc/rfc8259",
  "provenance": "original-work",
  "cases": [
    {
      "id": "json-8259-empty-object",
      "title": "Empty object is a JSON text",
      "section": "2",
      "section_title": "JSON Grammar",
      "section_url": "https://www.rfc-editor.org/rfc/rfc8259#section-2",
      "paragraph": "An object structure is represented as …",
      "requirement": "MUST",
      "expect": "accept",
      "input": "{}",
      "decoded": {}
    }
  ]
}
```

A **case** is one spec check. It is not a suite **data type**
(`message`, `document`, `telemetry`, `strings`, `event`). Those names
stay reserved for the benchmark sample shapes.

`input_encoding` is `utf-8` (default), `hex` (binary formats), or `latin-1`.

Regenerate original extras:

```bash
python3 compliance/scripts/write_corpus.py
```

Import official MIT/BSD suites (from local clones, no network at run time):

```bash
python3 compliance/scripts/import_official.py /tmp/compliance-suites
```

## Adding a language adapter

See [Language adapters](../docs/compliance/adapters.md). The catalog format
is language-agnostic. Python is implemented first.
