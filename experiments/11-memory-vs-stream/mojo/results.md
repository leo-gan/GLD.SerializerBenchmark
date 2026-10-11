# Experiment 11 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/11-memory-vs-stream/mojo/logs/mojo/2026-10-11-150812.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.69 | 2.03 | 2.73 | 114 | 0 | Avro | fastest | yes | 95 |
| mojo-json | 0.5.0 | 1.00 | 2.14 | 3.08 | 448 | 0 | JSON — mojo-json | close | yes | 97 |
| mojo-protobuf | 0.7.0 | 1.28 | 1.87 | 3.17 | 155 | 0 | Protocol Buffers | close | yes | 98 |
| mojo-flatbuffers | 0.4.0 | 3.45 | 1.58 | 5.07 | 408 | 0 | FlatBuffers | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 1.36 | 3.87 | 5.27 | 332 | 0 | CBOR | slower | yes | 94 |
| EmberJson | 0.3.4 | 3.78 | 3.45 | 7.20 | 448 | 0 | JSON — EmberJson | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 1.60 | 8.32 | 10.1 | 448 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 23.9 | 55.4 | 79.9 | 485 | 0 | TOML | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-json`, `mojo-protobuf`. Time/size front: `mojo-avro`.

