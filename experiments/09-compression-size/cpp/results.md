# Experiment 9 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/cpp/logs/cpp/2026-08-17-115911.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.62 | 0.35 | 0.98 | 50 | 71 | Protocol Buffers — in-tree wire helper | fastest | yes | 94 |
| msgpack | msgpack-cxx | 0.66 | 1.15 | 1.79 | 124 | 124 | MessagePack | slower | yes | 90 |
| nlohmann_json | 3.11.3 | 1.57 | 3.48 | 5.09 | 168 | 138 | JSON — common C++ library | slower | yes | 91 |
| simdjson | 3.10.1 | 0.11 | 5.67 | 5.79 | 168 | 138 | JSON — fast read from Experiment 1 | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 1.04 | 0.85 | 1.91 | 368 | 278 | Protocol Buffers — in-tree wire helper | fastest | yes | 96 |
| msgpack | msgpack-cxx | 0.85 | 1.31 | 2.17 | 346 | 274 | MessagePack | slower | yes | 88 |
| nlohmann_json | 3.11.3 | 2.19 | 4.94 | 7.15 | 411 | 281 | JSON — common C++ library | slower | yes | 89 |
| simdjson | 3.10.1 | 0.15 | 7.24 | 7.39 | 411 | 281 | JSON — fast read from Experiment 1 | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpack | msgpack-cxx | 1.58 | 2.08 | 3.67 | 1206 | 1165 | MessagePack | fastest | yes | 84 |
| protobuf-wire | wire-v2 | 3.58 | 1.52 | 5.07 | 1180 | 1141 | Protocol Buffers — in-tree wire helper | slower | yes | 96 |
| nlohmann_json | 3.11.3 | 9.76 | 24.3 | 34.0 | 2400 | 1305 | JSON — common C++ library | slower | yes | 84 |
| simdjson | 3.10.1 | 0.54 | 37.3 | 37.8 | 2400 | 1305 | JSON — fast read from Experiment 1 | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpack`. Small gap: —. Time/size front: `msgpack`, `protobuf-wire`.

