# Experiment 2 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/mojo/logs/mojo/2026-10-11-145915.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 0.51 | 0.70 | 1.21 | 50 | 0 | Protocol Buffers | fastest | yes | 90 |
| mojo-avro | 0.4.0 | 0.44 | 0.97 | 1.41 | 44 | 0 | Avro | close | yes | 87 |
| mojo-json | 0.5.0 | 0.74 | 1.39 | 2.10 | 164 | 0 | JSON — mojo-json | slower | yes | 95 |
| mojo-flatbuffers | 0.4.0 | 1.44 | 0.79 | 2.18 | 104 | 0 | FlatBuffers | slower | yes | 89 |
| mojo-cbor | 0.8.0 | 0.73 | 1.93 | 2.65 | 124 | 0 | CBOR | slower | yes | 86 |
| EmberJson | 0.3.4 | 2.40 | 2.44 | 4.94 | 168 | 0 | JSON — EmberJson | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 1.19 | 5.18 | 6.39 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 4.05 | 16.7 | 21.3 | 167 | 0 | TOML | slower | yes | 97 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 6.46 | 16.5 | 23.1 | 4841 | 0 | Protocol Buffers | fastest | yes | 92 |
| mojo-avro | 0.4.0 | 5.94 | 27.7 | 33.7 | 4051 | 0 | Avro | slower | yes | 85 |
| mojo-json | 0.5.0 | 10.7 | 24.4 | 35.2 | 16114 | 0 | JSON — mojo-json | slower | yes | 94 |
| mojo-flatbuffers | 0.4.0 | 29.7 | 15.9 | 45.6 | 8032 | 0 | FlatBuffers | slower | yes | 87 |
| EmberJson | 0.3.4 | 50.8 | 32.6 | 83.6 | 16556 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-cbor | 0.8.0 | 22.2 | 69.5 | 91.8 | 12037 | 0 | CBOR | slower | yes | 90 |
| ehsanmok-json | 0.4.0 | 20.0 | 231 | 252 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 436 | 1045 | 1490 | 17554 | 0 | TOML | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: `mojo-avro`. Time/size front: `mojo-protobuf`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

