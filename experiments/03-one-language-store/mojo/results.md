# Experiment 3 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/03-one-language-store/mojo/logs/mojo/2026-09-23-181448.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.10 | 0.46 | 0.56 | 44 | 0 | Avro | fastest | yes | 90 |
| mojo-protobuf | 0.6.0 | 0.11 | 0.47 | 0.59 | 50 | 0 | Protocol Buffers | similar | yes | 88 |
| mojo-json | 0.3.0 | 0.24 | 0.39 | 0.63 | 164 | 0 | JSON — mojo-json | slower | yes | 82 |
| EmberJson | 0.3.4 | 0.28 | 0.57 | 0.85 | 168 | 0 | JSON — EmberJson | slower | yes | 76 |
| mojo-flatbuffers | 0.2.0 | 0.80 | 0.27 | 1.06 | 104 | 0 | FlatBuffers | slower | yes | 79 |
| mojo-cbor | 0.6.0 | 0.17 | 1.37 | 1.54 | 124 | 0 | CBOR | slower | yes | 86 |
| ehsanmok-json | 0.4.0 | 0.36 | 3.37 | 3.72 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 82 |
| mojo-toml | 0.9.1 | 2.25 | 11.2 | 13.3 | 167 | 0 | TOML | slower | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

