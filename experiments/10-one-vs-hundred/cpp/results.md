# Experiment 10 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/10-one-vs-hundred/cpp/logs/cpp/2026-09-04-111828.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 2.35 | 1.55 | 3.85 | 138 | 2154 | Protocol Buffers — in-tree wire helper | fastest | yes | 85 |
| msgpack | msgpack-cxx | 1.64 | 2.90 | 4.57 | 214 | 2310 | MessagePack | slower | yes | 84 |
| simdjson | 3.10.1 | 4.27 | 7.86 | 12.0 | 272 | 2512 | JSON — fast read from Experiment 1 | slower | yes | 86 |
| nlohmann_json | 3.11.3 | 4.19 | 11.0 | 15.2 | 272 | 2512 | JSON — common C++ library | slower | yes | 89 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpack | msgpack-cxx | 88.2 | 112 | 201 | 19565 | 2310 | MessagePack | fastest | yes | 97 |
| protobuf-wire | wire-v2 | 162 | 106 | 268 | 12183 | 2154 | Protocol Buffers — in-tree wire helper | slower | yes | 97 |
| simdjson | 3.10.1 | 286 | 563 | 848 | 25463 | 2512 | JSON — fast read from Experiment 1 | slower | yes | 96 |
| nlohmann_json | 3.11.3 | 312 | 806 | 1136 | 25463 | 2512 | JSON — common C++ library | slower | yes | 94 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 1.83 | 0.94 | 2.81 | 50 | 2154 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| msgpack | msgpack-cxx | 1.68 | 3.45 | 5.24 | 124 | 2310 | MessagePack | slower | yes | 88 |
| simdjson | 3.10.1 | 4.48 | 7.77 | 12.3 | 168 | 2512 | JSON — fast read from Experiment 1 | slower | yes | 89 |
| nlohmann_json | 3.11.3 | 4.37 | 11.8 | 16.2 | 168 | 2512 | JSON — common C++ library | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 58.6 | 28.7 | 86.8 | 4841 | 2154 | Protocol Buffers — in-tree wire helper | fastest | yes | 98 |
| msgpack | msgpack-cxx | 44.0 | 65.7 | 109 | 12031 | 2310 | MessagePack | slower | yes | 99 |
| simdjson | 3.10.1 | 158 | 293 | 458 | 16546 | 2512 | JSON — fast read from Experiment 1 | slower | yes | 99 |
| nlohmann_json | 3.11.3 | 163 | 471 | 627 | 16546 | 2512 | JSON — common C++ library | slower | yes | 99 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample D (event), N = 100, memory** — not clearly slower: `msgpack`. Small gap: —. Time/size front: `msgpack`, `protobuf-wire`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

