# Experiment 2 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/02-flat-record-formats/mojo/logs/mojo/2026-09-09-132058.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.11 | 0.42 | 0.53 | 44 | 0 | Avro | fastest | yes | 95 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.44 | 0.54 | 50 | 0 | Protocol Buffers | similar | yes | 94 |
| EmberJson | 0.3.4 | 0.23 | 0.53 | 0.76 | 168 | 0 | JSON — EmberJson | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.17 | 1.28 | 1.44 | 124 | 0 | CBOR | slower | yes | 99 |
| mojo-json | 0.2.0 | 0.75 | 1.11 | 1.85 | 168 | 0 | JSON — mojo-json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 2.01 | 10.0 | 12.0 | 167 | 0 | TOML | slower | yes | 96 |
| ehsanmok-json | 0.3.0 | 10.0 | 3.19 | 13.2 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.43 | 30.6 | 36.0 | 4051 | 0 | Avro | fastest | yes | 93 |
| mojo-protobuf | 0.6.0 | 7.87 | 32.7 | 40.5 | 4841 | 0 | Protocol Buffers | slower | yes | 90 |
| EmberJson | 0.3.4 | 18.3 | 30.8 | 49.0 | 16556 | 0 | JSON — EmberJson | slower | yes | 88 |
| mojo-cbor | 0.6.0 | 9.85 | 113 | 123 | 12037 | 0 | CBOR | slower | yes | 83 |
| mojo-json | 0.2.0 | 70.8 | 101 | 172 | 16556 | 0 | JSON — mojo-json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 468 | 1016 | 1484 | 17554 | 0 | TOML | slower | yes | 83 |
| ehsanmok-json | 0.3.0 | 3765 | 308 | 4075 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

