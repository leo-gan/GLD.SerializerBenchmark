# Experiment 9 results — python

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/python/logs/python/2026-11-12-163740.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.42 | 1.23 | 2.66 | 52 | 72 | MessagePack | fastest | yes | 83 |
| orjson | 3.13.0 | 1.59 | 2.62 | 4.26 | 168 | 138 | JSON | slower | yes | 90 |
| protobuf | 7.36.2 | 3.28 | 2.68 | 5.92 | 50 | 71 | Protocol Buffers | slower | yes | 85 |
| json | python-3.14.0 | 9.72 | 8.07 | 17.8 | 168 | 138 | JSON — ships with Python | slower | yes | 84 |
| gld-kiln | 0.2.0 | 11.2 | 6.86 | 18.0 | 57 | 72 | positional binary — no field names | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 2.58 | 2.49 | 5.08 | 339 | 260 | MessagePack | fastest | yes | 89 |
| orjson | 3.13.0 | 2.42 | 3.04 | 5.51 | 410 | 270 | JSON | similar | yes | 83 |
| protobuf | 7.36.2 | 5.09 | 4.89 | 9.84 | 367 | 266 | Protocol Buffers | slower | yes | 93 |
| json | python-3.14.0 | 13.7 | 9.34 | 22.6 | 410 | 270 | JSON — ships with Python | slower | yes | 89 |
| gld-kiln | 0.2.0 | 29.1 | 20.6 | 49.8 | 435 | 286 | positional binary — no field names | slower | yes | 86 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 5.07 | 4.36 | 9.62 | 1190 | 1152 | MessagePack | fastest | yes | 93 |
| orjson | 3.13.0 | 5.91 | 6.65 | 12.5 | 2407 | 1317 | JSON | slower | yes | 91 |
| protobuf | 7.36.2 | 9.13 | 5.88 | 15.0 | 1061 | 1080 | Protocol Buffers | slower | yes | 70 |
| gld-kiln | 0.2.0 | 22.0 | 12.0 | 34.2 | 1073 | 1089 | positional binary — no field names | slower | yes | 91 |
| json | python-3.14.0 | 57.5 | 36.7 | 93.5 | 2407 | 1317 | JSON — ships with Python | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `msgspec-msgpack`, `orjson`. Small gap: —. Time/size front: `msgspec-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

