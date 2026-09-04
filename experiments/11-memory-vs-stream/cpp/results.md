# Experiment 11 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/11-memory-vs-stream/cpp/logs/cpp/2026-09-04-111847.csv`
**Language:** cpp
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 5.39 | 2.44 | 8.22 | 164 | 182 | Protocol Buffers — wire helper | fastest | yes | 97 |
| msgpack | msgpack-cxx | 3.68 | 6.02 | 9.84 | 332 | 228 | MessagePack | slower | yes | 96 |
| simdjson | 3.10.1 | 7.26 | 17.2 | 24.7 | 458 | 238 | JSON — fast read | slower | yes | 95 |
| nlohmann_json | 3.11.3 | 7.16 | 21.2 | 28.1 | 458 | 238 | JSON | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 3.88 | 2.00 | 5.93 | copied |
| msgpack | 1 | 2.26 | 4.55 | 6.84 | real |
| simdjson | 1 | 5.28 | 12.1 | 17.5 | copied |
| nlohmann_json | 1 | 6.83 | 18.0 | 24.9 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

