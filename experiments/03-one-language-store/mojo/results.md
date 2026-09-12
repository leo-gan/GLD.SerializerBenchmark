# Experiment 3 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/03-one-language-store/mojo/logs/mojo/2026-09-12-132620.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.09 | 0.43 | 0.52 | 44 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 0.11 | 0.42 | 0.53 | 50 | 0 | Protocol Buffers | close | yes | 94 |
| mojo-json | 0.3.0 | 0.22 | 0.35 | 0.58 | 164 | 0 | JSON — mojo-json | slower | yes | 95 |
| EmberJson | 0.3.4 | 0.25 | 0.53 | 0.78 | 168 | 0 | JSON — EmberJson | slower | yes | 95 |
| mojo-cbor | 0.6.0 | 0.17 | 1.27 | 1.44 | 124 | 0 | CBOR | slower | yes | 95 |
| ehsanmok-json | 0.3.1 | 0.54 | 3.44 | 3.98 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2.07 | 10.3 | 12.4 | 167 | 0 | TOML | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

