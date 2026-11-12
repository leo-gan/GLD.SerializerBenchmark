# Experiment 9 results — python

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/python/logs/python/2026-11-12-122315.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.23 | 1.36 | 2.69 | 52 | 72 | MessagePack | fastest | yes | 83 |
| orjson | 3.13.0 | 1.44 | 2.16 | 3.68 | 168 | 138 | JSON | slower | yes | 89 |
| protobuf | 7.36.2 | 2.85 | 2.44 | 5.32 | 50 | 71 | Protocol Buffers | slower | yes | 90 |
| json | python-3.14.0 | 9.16 | 7.40 | 16.4 | 168 | 138 | JSON — ships with Python | slower | yes | 86 |
| gld-kiln | 0.2.0 | 10.4 | 6.43 | 16.8 | 57 | 72 | positional binary — no field names | slower | yes | 89 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 2.13 | 2.37 | 4.32 | 339 | 260 | MessagePack | fastest | yes | 88 |
| orjson | 3.13.0 | 2.16 | 2.56 | 4.87 | 410 | 270 | JSON | similar | yes | 91 |
| protobuf | 7.36.2 | 3.58 | 3.63 | 7.29 | 367 | 266 | Protocol Buffers | slower | yes | 95 |
| json | python-3.14.0 | 12.0 | 7.79 | 19.8 | 410 | 270 | JSON — ships with Python | slower | yes | 89 |
| gld-kiln | 0.2.0 | 25.9 | 18.7 | 44.7 | 435 | 286 | positional binary — no field names | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 4.13 | 4.33 | 8.92 | 1190 | 1152 | MessagePack | fastest | yes | 84 |
| orjson | 3.13.0 | 5.31 | 5.91 | 11.3 | 2407 | 1317 | JSON | slower | yes | 91 |
| protobuf | 7.36.2 | 7.19 | 5.08 | 12.3 | 1061 | 1080 | Protocol Buffers | slower | yes | 81 |
| gld-kiln | 0.2.0 | 19.8 | 11.4 | 31.7 | 1073 | 1089 | positional binary — no field names | slower | yes | 95 |
| json | python-3.14.0 | 52.4 | 33.2 | 85.6 | 2407 | 1317 | JSON — ships with Python | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `msgspec-msgpack`, `orjson`. Small gap: —. Time/size front: `msgspec-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

