# Experiment 12 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/12-format-vs-library/cpp/logs/cpp/2026-08-17-103149.csv`
**Language:** cpp
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 2.23 | 6.82 | 9.07 | 458 | — | nlohmann — JSON | fastest | yes | 94 |
| nlohmann_cbor | 3.11.3 | 2.22 | 7.44 | 9.61 | 338 | — | nlohmann — CBOR | slower | yes | 96 |
| nlohmann_bson | 3.11.3 | 2.31 | 7.37 | 9.71 | 502 | — | nlohmann — BSON | slower | yes | 92 |
| nlohmann_msgpack | 3.11.3 | 2.23 | 7.61 | 9.85 | 332 | — | nlohmann — MessagePack | slower | yes | 93 |
| nlohmann_ubjson | 3.11.3 | 1.72 | 8.25 | 10.1 | 409 | — | nlohmann — UBJSON | slower | yes | 93 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| nlohmann_msgpack | 1 | 2.50 | 7.85 | 10.3 | real |
| nlohmann_cbor | 1 | 2.58 | 7.82 | 10.5 | real |
| nlohmann_bson | 1 | 2.91 | 8.16 | 11.1 | real |
| nlohmann_ubjson | 1 | 2.49 | 8.84 | 11.3 | real |
| nlohmann_json | 1 | 3.23 | 8.67 | 12.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`, `nlohmann_cbor`, `nlohmann_msgpack`.

