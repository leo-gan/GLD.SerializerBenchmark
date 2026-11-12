# Experiment 9 results — python

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/python/logs/python/2026-11-12-100805.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.12 | 1.36 | 2.52 | 52 | 72 | MessagePack | fastest | yes | 84 |
| orjson | 3.13.0 | 1.31 | 2.27 | 3.61 | 168 | 138 | JSON | slower | yes | 87 |
| protobuf | 7.36.2 | 3.30 | 2.69 | 6.02 | 50 | 71 | Protocol Buffers | slower | yes | 92 |
| gld-kiln | 0.2.0 | 11.4 | 7.07 | 18.5 | 57 | 72 | positional binary — no field names | slower | yes | 87 |
| json | python-3.14.0 | 10.5 | 8.10 | 18.6 | 168 | 138 | JSON — ships with Python | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.13.0 | 2.17 | 2.66 | 5.05 | 410 | 270 | JSON | fastest | yes | 92 |
| msgspec-msgpack | 0.21.1 | 2.41 | 2.71 | 5.27 | 339 | 260 | MessagePack | close | yes | 90 |
| protobuf | 7.36.2 | 5.11 | 4.91 | 10.1 | 367 | 266 | Protocol Buffers | slower | yes | 99 |
| json | python-3.14.0 | 15.0 | 9.80 | 25.2 | 410 | 270 | JSON — ships with Python | slower | yes | 99 |
| gld-kiln | 0.2.0 | 31.7 | 22.5 | 54.1 | 435 | 286 | positional binary — no field names | slower | yes | 98 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 4.36 | 4.50 | 8.84 | 1190 | 1152 | MessagePack | fastest | yes | 90 |
| orjson | 3.13.0 | 5.97 | 6.90 | 12.8 | 2407 | 1317 | JSON | slower | yes | 92 |
| protobuf | 7.36.2 | 8.40 | 6.04 | 14.3 | 1061 | 1080 | Protocol Buffers | slower | yes | 93 |
| gld-kiln | 0.2.0 | 21.1 | 12.3 | 33.4 | 1073 | 1089 | positional binary — no field names | slower | yes | 86 |
| json | python-3.14.0 | 60.4 | 37.5 | 97.7 | 2407 | 1317 | JSON — ships with Python | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `orjson`. Small gap: `msgspec-msgpack`. Time/size front: `orjson`, `msgspec-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

