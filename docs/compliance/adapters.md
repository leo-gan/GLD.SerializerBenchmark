# Language adapters

The catalog files are **language-agnostic JSON**. Python is implemented
first. Another language should not clone the catalog; it should read
the same files.

## Contract

For each case:

1. Decode `input` (UTF-8 text, or hex → bytes when
   `input_encoding` is `hex`).
2. If `expect` is `reject`, the decode must fail.
3. If `expect` is `accept` and `decoded` is present, the host value
   must match (JSON-like equality: numbers may be int or float;
   `{"$hex":"00ff"}` means a byte string).
4. On mismatch, print the block in
   [Reading failures](reading-results.md), including `section_url`.

Do **not** download suites at run time. Do **not** add a submodule.

## Python

Package: `python/src/compliance/`.

```text
compliance.catalog     load the catalog
compliance.adapters    json / orjson / msgspec / rapidjson / pydantic /
                       mashumaro / serpyco-rs / yaml / tomllib / cbor2 /
                       msgpack / protobuf / fastavro / bson / flexbuffers /
                       amazon-ion / py-ubjson / newsmile / plistlib

JavaScript: `javascript/src/compliance.mjs` (JSON.parse, js-yaml,
cbor-x, msgpackr, bson, avsc, flexbuffers, protobufjs wire scan).
compliance.runner      run_suites()
compliance.report       format_summary() / JSON sidecar
```

Public command (from the repo root):

```bash
./scripts/run-compliance.sh
./scripts/run-compliance.sh --format json --serializer orjson
./scripts/run-compliance.sh --detailed --json-out logs/compliance/out.json
```

To add a Python library, append an `Adapter` in
`python/src/compliance/adapters.py` (`name`, `format`, `decode`,
optional `encode`).

## Sketch for another language

1. Parse every `compliance/data/*/*.json`.
2. Skip `decoded` comparison when the host type cannot represent it
   (for example MessagePack ext → accept-only).
3. Keep the run **report-only** unless you are testing the runner.
4. Link the same `section_url` in the diagnostic.

A Go or JavaScript runner can live next to that language’s tests and
import the catalog by relative path from the repo root. Do not copy
the JSON into `go/` or `javascript/` — one corpus.
