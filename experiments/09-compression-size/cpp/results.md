# Experiment 9 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/09-compression-size/cpp/logs/cpp/2026-09-04-111822.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 1.64 | 0.78 | 2.44 | 50 | 71 | Protocol Buffers — in-tree wire helper | fastest | yes | 89 |
| msgpack | msgpack-cxx | 1.74 | 2.99 | 4.75 | 124 | 124 | MessagePack | slower | yes | 93 |
| simdjson | 3.10.1 | 3.72 | 5.86 | 9.75 | 168 | 138 | JSON — fast read from Experiment 1 | slower | yes | 94 |
| nlohmann_json | 3.11.3 | 3.89 | 9.66 | 13.5 | 168 | 138 | JSON — common C++ library | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 2.04 | 1.82 | 3.90 | 368 | 278 | Protocol Buffers — in-tree wire helper | fastest | yes | 85 |
| msgpack | msgpack-cxx | 1.76 | 3.25 | 5.08 | 346 | 274 | MessagePack | slower | yes | 91 |
| simdjson | 3.10.1 | 5.27 | 10.1 | 15.4 | 411 | 281 | JSON — fast read from Experiment 1 | slower | yes | 95 |
| nlohmann_json | 3.11.3 | 5.28 | 12.8 | 18.1 | 411 | 281 | JSON — common C++ library | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpack | msgpack-cxx | 4.18 | 6.78 | 10.8 | 1206 | 1165 | MessagePack | fastest | yes | 95 |
| protobuf-wire | wire-v2 | 7.75 | 4.07 | 11.8 | 1180 | 1141 | Protocol Buffers — in-tree wire helper | close | yes | 94 |
| simdjson | 3.10.1 | 22.7 | 22.7 | 46.1 | 2400 | 1305 | JSON — fast read from Experiment 1 | slower | yes | 99 |
| nlohmann_json | 3.11.3 | 23.2 | 60.5 | 83.8 | 2400 | 1305 | JSON — common C++ library | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpack`. Small gap: `protobuf-wire`. Time/size front: `msgpack`, `protobuf-wire`.

