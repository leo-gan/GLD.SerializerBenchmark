# Experiment 12 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/12-format-vs-library/javascript/logs/javascript/2026-08-17-103213.csv`
**Language:** javascript
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| google-protobuf | 3.21.4 | 0.71 | 15.4 | 16.0 | 155 | — | Protocol Buffers — google-protobuf | fastest | yes | 89 |
| protobufjs | 7.6.5 | 12.5 | 26.1 | 38.7 | 155 | — | Protocol Buffers — protobufjs | slower | yes | 89 |
| protobuf-es | 2.12.1 | 35.0 | 30.8 | 68.9 | 155 | — | Protocol Buffers — protobuf-es | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `google-protobuf`. Small gap: —. Time/size front: `google-protobuf`.

