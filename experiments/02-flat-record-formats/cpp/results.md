# Experiment 2 results — cpp

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/cpp/logs/cpp/2026-08-16-154215.csv`
**Language:** cpp
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.34 | 0.20 | 0.54 | 50 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 95 |
| msgpack | msgpack-cxx | 0.56 | 0.53 | 1.09 | 124 | — | MessagePack | slower | yes | 90 |
| simdjson | 3.10.1 | 0.08 | 3.01 | 3.09 | 168 | — | JSON — fast read from Experiment 1 | slower | yes | 91 |
| nlohmann_json | 3.11.3 | 1.02 | 2.46 | 3.48 | 168 | — | JSON — common C++ library | slower | yes | 88 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 25.4 | 11.9 | 37.7 | 4841 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 96 |
| msgpack | msgpack-cxx | 17.8 | 19.8 | 38.1 | 12031 | — | MessagePack | similar | yes | 91 |
| simdjson | 3.10.1 | 3.08 | 213 | 219 | 16546 | — | JSON — fast read from Experiment 1 | slower | yes | 92 |
| nlohmann_json | 3.11.3 | 52.6 | 175 | 229 | 16546 | — | JSON — common C++ library | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.37 | 0.22 | 0.59 | copied |
| msgpack | 1 | 0.40 | 0.91 | 1.31 | real |
| simdjson | 1 | 0.10 | 3.10 | 3.21 | copied |
| nlohmann_json | 1 | 1.25 | 3.01 | 4.25 | real |
| protobuf-wire | 100 | 26.4 | 12.0 | 38.8 | copied |
| msgpack | 100 | 19.7 | 22.4 | 42.3 | real |
| simdjson | 100 | 5.71 | 214 | 222 | copied |
| nlohmann_json | 100 | 71.9 | 215 | 287 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**N = 100, memory** — not clearly slower: `protobuf-wire`, `msgpack`. Small gap: —. Time/size front: `protobuf-wire`.

