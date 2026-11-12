# Experiment 9 results — cpp

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/cpp/logs/cpp/2026-11-12-100841.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.32 | 0.36 | 0.68 | 57 | 72 | positional binary — no field names | fastest | yes | 81 |
| protobuf-wire | wire-v2 | 0.77 | 0.38 | 1.15 | 50 | 71 | Protocol Buffers — in-tree wire helper | slower | yes | 88 |
| msgpack | msgpack-cxx | 0.92 | 1.44 | 2.38 | 124 | 124 | MessagePack | slower | yes | 87 |
| simdjson | 3.13.0 | 1.73 | 3.06 | 4.92 | 168 | 138 | JSON — fast read fast named JSON | slower | yes | 89 |
| nlohmann_json | 3.12.0 | 1.78 | 4.63 | 6.49 | 168 | 138 | JSON — common C++ library | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.81 | 0.96 | 1.79 | 435 | 286 | positional binary — no field names | fastest | yes | 89 |
| protobuf-wire | wire-v2 | 1.20 | 0.87 | 2.08 | 367 | 266 | Protocol Buffers — in-tree wire helper | slower | yes | 87 |
| msgpack | msgpack-cxx | 0.94 | 1.46 | 2.40 | 345 | 265 | MessagePack | slower | yes | 86 |
| simdjson | 3.13.0 | 2.22 | 4.49 | 6.74 | 410 | 270 | JSON — fast read fast named JSON | slower | yes | 89 |
| nlohmann_json | 3.12.0 | 2.25 | 5.96 | 8.30 | 410 | 270 | JSON — common C++ library | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.77 | 0.67 | 1.44 | 1067 | 1084 | positional binary — no field names | fastest | yes | 97 |
| msgpack | msgpack-cxx | 2.20 | 3.03 | 5.42 | 1206 | 1165 | MessagePack | slower | yes | 96 |
| protobuf-wire | wire-v2 | 4.43 | 1.58 | 6.02 | 1180 | 1141 | Protocol Buffers — in-tree wire helper | slower | yes | 89 |
| simdjson | 3.13.0 | 11.1 | 10.1 | 21.1 | 2400 | 1305 | JSON — fast read fast named JSON | slower | yes | 91 |
| nlohmann_json | 3.12.0 | 11.1 | 30.1 | 41.2 | 2400 | 1305 | JSON — common C++ library | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf-wire`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf-wire`, `msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`.

