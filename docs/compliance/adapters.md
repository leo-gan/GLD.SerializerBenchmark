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

## Arrow, Parquet, ORC, and SBE

These formats have corpora next to the other standards:

| Format id | File | What a case checks |
| --- | --- | --- |
| `arrow` | `compliance/data/arrow/ipc-stream.json` | IPC stream: two `berth` rows, empty buffer, bad continuation, truncated metadata |
| `parquet` | `compliance/data/parquet/file-format.json` | Uncompressed file: two `berth` rows, empty buffer, bad trailing magic, truncated footer |
| `orc` | `compliance/data/orc/v1.json` | ORC v1: two `berth` rows, empty buffer, postscript length 0, truncated header |
| `sbe` | `compliance/data/sbe/v1.0.json` | One raw Signal message: one leg, no legs, empty buffer, truncated block, wrong template id |

The bytes are original cases for this suite (column name `berth`, symbol `kelp`, venue `harbor`). They are frozen in the JSON files. Do not regenerate them while scoring, and do not download another project’s suite.

Each language decodes with its own reader: pyarrow, Arrow C++, arrow-rs, arrow-go, Apache Arrow Java, Apache.Arrow, hyparquet, parquet-java, Parquet.Net, orc-core, and the sbe-tool 1.40.2 codec generated for that language. `parquet` and `parquet-uncompressed` share that language’s Parquet reader. `orc` and `orc-uncompressed` share that language’s ORC reader. A language with no ORC or SBE library has no adapter and no cell.

Python and C# record `mapped serializer has no <format> adapter` once `compliance/data/<format>/` exists. Do not score one library with another library’s decoder.

## Python

Package: `python/src/compliance/`.

```text
compliance.catalog     load the catalog
compliance.adapters    json / orjson / msgspec / rapidjson / pydantic /
                       mashumaro / serpyco-rs / yaml / tomllib / cbor2 /
                       msgpack / protobuf / fastavro / bson / flexbuffers /
                       amazon-ion / py-ubjson / newsmile / plistlib /
                       pyarrow (Arrow IPC, Parquet, ORC)

JavaScript: `javascript/src/compliance.mjs`. Other languages have a
`compliance` entry next to the bench runner (`go/compliance`,
`rust/src/bin/compliance.rs`, `java` `benchmark.Compliance`,
`kotlin` `complianceMain`, `c-sharp` `dotnet run -- compliance`,
`php/src/compliance.php`, `cpp/src/compliance.cpp`,
`swift/compliance.swift`, `zig/src/compliance.zig`, `mojo/src/compliance.mojo`).
`./scripts/run-compliance.sh` runs every toolchain it finds.

Protobuf uses the catalog `Doc` message (`n`, `s`, `ok`, `tags`). Official
runtimes (Python, Go, Java, Kotlin, Rust prost, C# Google.Protobuf /
protobuf-net, JS protobufjs, PHP, Mojo gld-protobuf) decode it. C, C++,
Swift, and Zig use a small wire reader that implements the same encoding
guide so those columns are not empty.
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

## One row, one library

A row is a claim about the library it names, so its decode must go through
that library's own API. Two rows that share a decoder are one measurement
published twice, and a reader comparing them sees agreement the catalog
never tested. If a library exposes no entry point that can answer "is this
input valid?", leave it out of `compliance/serializer-standards.json` for
that format rather than filling the column with another implementation's
verdict.

When a decoder cannot be handed an input without taking the runner down —
it does not terminate, or it aborts — record the case as `skip` with a
reason. A `reject` the library never made would score as a deviation it
does not have. Name the defect in the guard so the guard can be deleted
when the fix ships.

## Sketch for another language

1. Parse every `compliance/data/*/*.json`.
2. Skip `decoded` comparison when the host type cannot represent it
   (for example MessagePack ext → accept-only).
3. Keep the run **report-only** unless you are testing the runner.
4. Link the same `section_url` in the diagnostic.

A Go or JavaScript runner can live next to that language’s tests and
import the catalog by relative path from the repo root. Do not copy
the JSON into `go/` or `javascript/` — one corpus.
