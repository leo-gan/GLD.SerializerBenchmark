# Experiment 12 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/12-format-vs-library/java/logs/java/2026-08-17-103142.csv`
**Language:** java
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 23.1 | 22.9 | 48.6 | 440 | — | JSON — another library (jsoniter, Experiment 1) | fastest | yes | 88 |
| gson | 2.12.1 | 46.8 | 43.8 | 91.6 | 440 | — | JSON — another library (Gson) | slower | yes | 84 |
| jackson-smile | 2.18.3 | 45.5 | 56.2 | 104 | 233 | — | Jackson — Smile | slower | yes | 89 |
| jackson-cbor | 2.18.3 | 43.1 | 59.1 | 105 | 334 | — | Jackson — CBOR | slower | yes | 83 |
| jackson | 2.18.3 | 46.6 | 60.1 | 110 | 440 | — | Jackson — JSON | slower | yes | 87 |
| msgpack | 0.9.8 | 70.3 | 63.2 | 132 | 317 | — | Jackson — MessagePack | slower | yes | 82 |
| ion | 2.18.3 | 112 | 149 | 258 | 380 | — | Jackson — Ion | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| jsoniter | 1 | 11.3 | 12.7 | 23.8 | copied |
| jackson-smile | 1 | 17.4 | 20.0 | 37.5 | real |
| jackson-cbor | 1 | 19.3 | 20.3 | 39.8 | real |
| jackson | 1 | 17.7 | 23.3 | 41.7 | real |
| msgpack | 1 | 25.4 | 23.0 | 52.4 | real |
| gson | 1 | 40.0 | 24.6 | 66.1 | real |
| ion | 1 | 50.9 | 64.1 | 119 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `jackson-smile`.

