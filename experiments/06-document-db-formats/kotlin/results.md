# Experiment 6 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/06-document-db-formats/kotlin/logs/kotlin/2026-10-11-150303.csv`
**Language:** kotlin
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.19.0 | 69.8 | 107 | 171 | 440 | 230 | JSON — Jackson | fastest | yes | 89 |
| jackson-cbor | 2.19.0 | 69.1 | 104 | 172 | 334 | 222 | CBOR — Jackson | similar | yes | 86 |
| kotlinx-ion | 1.11.11 | 124 | 89.0 | 219 | 234 | 253 | Ion | close | yes | 89 |
| msgpack | 0.9.8 | 94.1 | 112 | 222 | 317 | 227 | MessagePack | close | yes | 89 |
| kbson | 0.5.0 | 144 | 87.7 | 234 | 1000 | 286 | BSON | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jackson`, `jackson-cbor`. Small gap: `kotlinx-ion`, `msgpack`. Time/size front: `jackson`, `jackson-cbor`, `kotlinx-ion`.

