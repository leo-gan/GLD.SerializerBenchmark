# Experiment 10 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/cpp/logs/cpp/2026-08-17-110707.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.92 | 0.56 | 1.49 | 138 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 93 |
| msgpack | msgpack-cxx | 0.94 | 0.92 | 1.90 | 214 | — | MessagePack | slower | yes | 95 |
| simdjson | 3.10.1 | 0.12 | 5.43 | 5.55 | 272 | — | JSON — fast read from Experiment 1 | slower | yes | 90 |
| nlohmann_json | 3.11.3 | 1.64 | 4.15 | 5.74 | 272 | — | JSON — common C++ library | slower | yes | 96 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpack | msgpack-cxx | 41.1 | 42.5 | 84.1 | 19565 | — | MessagePack | fastest | yes | 94 |
| protobuf-wire | wire-v2 | 73.3 | 46.0 | 121 | 12183 | — | Protocol Buffers — in-tree wire helper | slower | yes | 94 |
| simdjson | 3.10.1 | 5.29 | 372 | 378 | 25463 | — | JSON — fast read from Experiment 1 | slower | yes | 76 |
| nlohmann_json | 3.11.3 | 110 | 300 | 411 | 25463 | — | JSON — common C++ library | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.37 | 0.19 | 0.56 | 50 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 97 |
| msgpack | msgpack-cxx | 0.51 | 0.64 | 1.18 | 124 | — | MessagePack | slower | yes | 94 |
| nlohmann_json | 3.11.3 | 1.09 | 2.65 | 3.75 | 168 | — | JSON — common C++ library | slower | yes | 89 |
| simdjson | 3.10.1 | 0.10 | 3.67 | 3.77 | 168 | — | JSON — fast read from Experiment 1 | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 26.9 | 12.9 | 40.2 | 4841 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 91 |
| msgpack | msgpack-cxx | 20.1 | 26.4 | 47.0 | 12031 | — | MessagePack | slower | yes | 95 |
| simdjson | 3.10.1 | 3.24 | 237 | 241 | 16546 | — | JSON — fast read from Experiment 1 | slower | yes | 73 |
| nlohmann_json | 3.11.3 | 56.9 | 187 | 245 | 16546 | — | JSON — common C++ library | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample D (event), N = 100, memory** — not clearly slower: `msgpack`. Small gap: —. Time/size front: `msgpack`, `protobuf-wire`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

