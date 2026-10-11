# Experiment 3 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/03-one-language-store/mojo/logs/mojo/2026-10-11-145952.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 0.54 | 0.79 | 1.35 | 50 | 0 | Protocol Buffers | fastest | yes | 92 |
| mojo-avro | 0.4.0 | 0.50 | 1.14 | 1.64 | 44 | 0 | Avro | slower | yes | 91 |
| mojo-json | 0.5.0 | 0.76 | 1.52 | 2.35 | 164 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-flatbuffers | 0.4.0 | 1.68 | 0.84 | 2.53 | 104 | 0 | FlatBuffers | slower | yes | 94 |
| mojo-cbor | 0.8.0 | 0.80 | 2.13 | 2.96 | 124 | 0 | CBOR | slower | yes | 89 |
| EmberJson | 0.3.4 | 2.60 | 2.72 | 5.36 | 168 | 0 | JSON — EmberJson | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 1.30 | 5.41 | 6.77 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 4.40 | 17.1 | 21.5 | 167 | 0 | TOML | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

