# Experiment 9 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/python/logs/python/2026-09-29-184517.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.11 | 1.35 | 2.47 | 52 | 72 | MessagePack | fastest | yes | 84 |
| orjson | 3.12.0 | 1.24 | 1.83 | 2.95 | 168 | 138 | JSON | close | yes | 84 |
| protobuf | 7.36.1 | 2.55 | 2.42 | 5.06 | 50 | 71 | Protocol Buffers | slower | yes | 84 |
| json | python-3.14.0 | 9.89 | 8.13 | 18.0 | 168 | 138 | JSON — ships with Python | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.89 | 2.36 | 4.28 | 339 | 260 | MessagePack | fastest | yes | 84 |
| orjson | 3.12.0 | 2.05 | 2.19 | 4.40 | 410 | 270 | JSON | similar | yes | 86 |
| protobuf | 7.36.1 | 3.11 | 3.73 | 6.92 | 367 | 266 | Protocol Buffers | slower | yes | 91 |
| json | python-3.14.0 | 12.1 | 8.26 | 20.4 | 410 | 270 | JSON — ships with Python | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 3.92 | 4.33 | 8.60 | 1190 | 1152 | MessagePack | fastest | yes | 84 |
| orjson | 3.12.0 | 5.20 | 5.34 | 10.8 | 2407 | 1317 | JSON | slower | yes | 91 |
| protobuf | 7.36.1 | 8.24 | 5.60 | 13.8 | 1061 | 1080 | Protocol Buffers | slower | yes | 94 |
| json | python-3.14.0 | 59.9 | 37.3 | 97.4 | 2407 | 1317 | JSON — ships with Python | slower | yes | 97 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: `orjson`. Time/size front: `msgspec-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `msgspec-msgpack`, `orjson`. Small gap: —. Time/size front: `msgspec-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

