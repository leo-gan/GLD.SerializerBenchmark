# Experiment 6 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/06-document-db-formats/kotlin/logs/kotlin/2026-08-27-181738.csv`
**Language:** kotlin
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson-cbor | 2.18.3 | 57.5 | 82.2 | 140 | 334 | 222 | CBOR — Jackson | fastest | yes | 81 |
| jackson | 2.18.3 | 55.4 | 91.1 | 150 | 440 | 230 | JSON — Jackson | similar | yes | 84 |
| msgpack | 0.9.8 | 71.7 | 90.1 | 162 | 317 | 227 | MessagePack | slower | yes | 82 |
| kotlinx-ion | 1.11.11 | 110 | 73.3 | 183 | 234 | 253 | Ion | slower | yes | 91 |
| kbson | 0.5.0 | 107 | 85.3 | 191 | 1032 | 286 | BSON | slower | yes | 79 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jackson-cbor`, `jackson`. Small gap: —. Time/size front: `jackson-cbor`, `msgpack`, `kotlinx-ion`.

