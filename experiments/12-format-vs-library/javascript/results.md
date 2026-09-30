# Experiment 12 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/12-format-vs-library/javascript/logs/javascript/2026-09-29-184748.csv`
**Language:** javascript
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobufjs | 7.6.6 | 14.7 | 10.1 | 27.1 | 155 | 174 | Protocol Buffers — protobufjs | fastest | yes | 90 |
| google-protobuf | 3.21.4 | 22.4 | 17.5 | 40.3 | 155 | 174 | Protocol Buffers — google-protobuf | slower | yes | 89 |
| protobuf-es | 2.15.0 | 22.4 | 18.3 | 40.7 | 155 | 174 | Protocol Buffers — protobuf-es | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `protobufjs`. Small gap: —. Time/size front: `protobufjs`.

