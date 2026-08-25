# Experiment 11 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/11-memory-vs-stream/cpp/logs/cpp/2026-08-17-110931.csv`
**Language:** cpp
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 1.39 | 0.71 | 2.08 | 164 | — | Protocol Buffers — wire helper | fastest | yes | 95 |
| msgpack | msgpack-cxx | 1.44 | 1.25 | 2.74 | 332 | — | MessagePack | slower | yes | 95 |
| simdjson | 3.10.1 | 0.13 | 8.98 | 9.11 | 458 | — | JSON — fast read | slower | yes | 92 |
| nlohmann_json | 3.11.3 | 2.25 | 6.91 | 9.19 | 458 | — | JSON | slower | yes | 92 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 1.45 | 0.73 | 2.16 | copied |
| msgpack | 1 | 0.92 | 1.90 | 2.86 | real |
| simdjson | 1 | 0.14 | 9.01 | 9.16 | copied |
| nlohmann_json | 1 | 3.14 | 8.47 | 11.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

