# Experiment 6 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/java/logs/java/2026-08-17-110009.csv`
**Language:** java
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson-smile | 2.18.3 | 44.6 | 49.5 | 95.6 | 233 | — | Smile — Jackson | fastest | yes | 86 |
| jackson | 2.18.3 | 52.0 | 55.5 | 114 | 440 | — | JSON — Jackson | similar | yes | 86 |
| jackson-cbor | 2.18.3 | 51.9 | 61.8 | 117 | 334 | — | CBOR — Jackson | similar | yes | 87 |
| msgpack | 0.9.8 | 79.1 | 62.8 | 150 | 317 | — | MessagePack — Jackson | slower | yes | 87 |
| bson | 5.3.1 | 89.0 | 84.9 | 171 | 517 | — | BSON | slower | yes | 90 |
| ion | 2.18.3 | 130 | 161 | 297 | 380 | — | Ion — Jackson | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jackson-smile`, `jackson`, `jackson-cbor`. Small gap: —. Time/size front: `jackson-smile`.

