# Experiment 2 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/02-flat-record-formats/cpp/logs/cpp/2026-09-04-111744.csv`
**Language:** cpp
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 1.42 | 0.81 | 2.25 | 50 | 2114 | Protocol Buffers — in-tree wire helper | fastest | yes | 80 |
| msgpack | msgpack-cxx | 1.41 | 2.77 | 4.15 | 124 | 2280 | MessagePack | slower | yes | 82 |
| simdjson | 3.10.1 | 3.51 | 6.47 | 10.2 | 168 | 2484 | JSON — fast read from Experiment 1 | slower | yes | 92 |
| nlohmann_json | 3.11.3 | 3.44 | 9.52 | 12.9 | 168 | 2484 | JSON — common C++ library | slower | yes | 83 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 35.3 | 17.9 | 53.6 | 4841 | 2114 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| msgpack | msgpack-cxx | 25.9 | 38.1 | 64.6 | 12031 | 2280 | MessagePack | slower | yes | 89 |
| simdjson | 3.10.1 | 75.8 | 169 | 245 | 16546 | 2484 | JSON — fast read from Experiment 1 | slower | yes | 88 |
| nlohmann_json | 3.11.3 | 76.4 | 279 | 357 | 16546 | 2484 | JSON — common C++ library | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 1.55 | 0.90 | 2.43 | copied |
| msgpack | 1 | 1.51 | 3.94 | 5.42 | real |
| simdjson | 1 | 4.10 | 7.08 | 11.2 | copied |
| nlohmann_json | 1 | 4.84 | 11.2 | 16.2 | real |
| protobuf-wire | 100 | 37.0 | 18.9 | 55.9 | copied |
| msgpack | 100 | 27.2 | 39.3 | 66.9 | real |
| simdjson | 100 | 80.5 | 172 | 254 | copied |
| nlohmann_json | 100 | 108 | 295 | 404 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

