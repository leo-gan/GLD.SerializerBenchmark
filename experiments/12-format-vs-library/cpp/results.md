# Experiment 12 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/12-format-vs-library/cpp/logs/cpp/2026-09-04-111852.csv`
**Language:** cpp
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 6.75 | 19.0 | 26.0 | 458 | 238 | nlohmann — JSON | fastest | yes | 96 |
| nlohmann_bson | 3.11.3 | 6.96 | 19.3 | 26.0 | 502 | 288 | nlohmann — BSON | similar | yes | 95 |
| nlohmann_msgpack | 3.11.3 | 6.57 | 19.4 | 26.1 | 332 | 226 | nlohmann — MessagePack | similar | yes | 93 |
| nlohmann_cbor | 3.11.3 | 6.65 | 19.8 | 26.4 | 338 | 221 | nlohmann — CBOR | similar | yes | 89 |
| nlohmann_ubjson | 3.11.3 | 5.70 | 21.4 | 27.0 | 409 | 243 | nlohmann — UBJSON | similar | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| nlohmann_msgpack | 1 | 5.03 | 15.4 | 20.5 | real |
| nlohmann_cbor | 1 | 5.21 | 15.5 | 21.0 | real |
| nlohmann_bson | 1 | 5.61 | 16.1 | 21.7 | real |
| nlohmann_ubjson | 1 | 4.93 | 16.5 | 21.8 | real |
| nlohmann_json | 1 | 5.98 | 16.1 | 22.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `nlohmann_json`, `nlohmann_bson`, `nlohmann_msgpack`, `nlohmann_cbor`, `nlohmann_ubjson`. Small gap: —. Time/size front: `nlohmann_json`, `nlohmann_msgpack`.

