# Experiment 2 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/02-flat-record-formats/mojo/logs/mojo/2026-09-23-181437.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.11 | 0.47 | 0.58 | 44 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 0.12 | 0.49 | 0.60 | 50 | 0 | Protocol Buffers | similar | yes | 96 |
| mojo-json | 0.3.0 | 0.25 | 0.40 | 0.66 | 164 | 0 | JSON — mojo-json | slower | yes | 90 |
| EmberJson | 0.3.4 | 0.28 | 0.59 | 0.87 | 168 | 0 | JSON — EmberJson | slower | yes | 88 |
| mojo-flatbuffers | 0.2.0 | 0.81 | 0.26 | 1.05 | 104 | 0 | FlatBuffers | slower | yes | 88 |
| mojo-cbor | 0.6.0 | 0.18 | 1.41 | 1.59 | 124 | 0 | CBOR | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 0.37 | 3.43 | 3.78 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2.27 | 11.4 | 13.7 | 167 | 0 | TOML | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.50 | 34.2 | 39.7 | 4051 | 0 | Avro | fastest | yes | 85 |
| mojo-json | 0.3.0 | 15.8 | 28.4 | 44.5 | 16114 | 0 | JSON — mojo-json | slower | yes | 89 |
| mojo-protobuf | 0.6.0 | 9.20 | 37.0 | 46.9 | 4841 | 0 | Protocol Buffers | slower | yes | 90 |
| EmberJson | 0.3.4 | 21.0 | 35.6 | 57.2 | 16556 | 0 | JSON — EmberJson | slower | yes | 91 |
| mojo-flatbuffers | 0.2.0 | 64.8 | 19.6 | 84.9 | 8032 | 0 | FlatBuffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 10.6 | 124 | 135 | 12037 | 0 | CBOR | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 21.3 | 291 | 314 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 521 | 1148 | 1660 | 17554 | 0 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

