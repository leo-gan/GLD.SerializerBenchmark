# Experiment 2 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/02-flat-record-formats/mojo/logs/mojo/2026-09-08-155323.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.10 | 0.43 | 0.53 | 44 | 0 | Avro | fastest | yes | 97 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.45 | 0.55 | 50 | 0 | Protocol Buffers | close | yes | 96 |
| EmberJson | 0.3.4 | 0.25 | 0.54 | 0.78 | 168 | 0 | JSON — EmberJson | slower | yes | 96 |
| mojo-cbor | 0.6.0 | 0.18 | 1.30 | 1.48 | 124 | 0 | CBOR | slower | yes | 97 |
| mojo-toml | 0.9.1 | 2.05 | 10.3 | 12.3 | 167 | 0 | TOML | slower | yes | 96 |
| ehsanmok-json | 0.3.0 | 10.3 | 3.26 | 13.5 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 96 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.19 | 31.3 | 36.6 | 4051 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 8.33 | 33.6 | 42.0 | 4841 | 0 | Protocol Buffers | slower | yes | 91 |
| EmberJson | 0.3.4 | 19.2 | 33.1 | 52.3 | 16556 | 0 | JSON — EmberJson | slower | yes | 96 |
| mojo-cbor | 0.6.0 | 10.6 | 117 | 128 | 12037 | 0 | CBOR | slower | yes | 92 |
| mojo-toml | 0.9.1 | 487 | 1059 | 1548 | 17554 | 0 | TOML | slower | yes | 97 |
| ehsanmok-json | 0.3.0 | 3883 | 310 | 4192 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

