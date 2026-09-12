# Experiment 2 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/02-flat-record-formats/mojo/logs/mojo/2026-09-12-132612.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.6.0 | 0.11 | 0.44 | 0.55 | 50 | 0 | Protocol Buffers | fastest | yes | 77 |
| mojo-avro | 0.4.0 | 0.10 | 0.45 | 0.55 | 44 | 0 | Avro | similar | yes | 81 |
| mojo-json | 0.3.0 | 0.24 | 0.36 | 0.60 | 164 | 0 | JSON — mojo-json | slower | yes | 76 |
| EmberJson | 0.3.4 | 0.26 | 0.56 | 0.82 | 168 | 0 | JSON — EmberJson | slower | yes | 81 |
| mojo-cbor | 0.6.0 | 0.18 | 1.33 | 1.50 | 124 | 0 | CBOR | slower | yes | 81 |
| ehsanmok-json | 0.3.1 | 0.58 | 3.61 | 4.19 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 2.12 | 10.9 | 13.2 | 167 | 0 | TOML | slower | yes | 93 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.24 | 32.9 | 38.3 | 4051 | 0 | Avro | fastest | yes | 90 |
| mojo-json | 0.3.0 | 15.5 | 27.2 | 42.7 | 16114 | 0 | JSON — mojo-json | slower | yes | 86 |
| mojo-protobuf | 0.6.0 | 8.12 | 34.9 | 43.1 | 4841 | 0 | Protocol Buffers | slower | yes | 82 |
| EmberJson | 0.3.4 | 19.6 | 32.7 | 52.2 | 16556 | 0 | JSON — EmberJson | slower | yes | 87 |
| mojo-cbor | 0.6.0 | 10.3 | 120 | 131 | 12037 | 0 | CBOR | slower | yes | 88 |
| ehsanmok-json | 0.3.1 | 45.6 | 309 | 355 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 501 | 1080 | 1577 | 17554 | 0 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `mojo-protobuf`, `mojo-avro`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

