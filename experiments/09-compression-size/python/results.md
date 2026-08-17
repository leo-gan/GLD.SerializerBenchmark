# Experiment 9 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/python/logs/python/2026-08-17-110534.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 0.73 | 1.11 | 1.85 | 168 | 138 | JSON | fastest | yes | 89 |
| msgspec-msgpack | 0.21.1 | 0.77 | 1.16 | 1.96 | 52 | 72 | MessagePack | close | yes | 83 |
| protobuf | 7.35.1 | 1.68 | 1.63 | 3.35 | 50 | 71 | Protocol Buffers | slower | yes | 81 |
| json | python-3.14.0 | 7.81 | 4.77 | 12.5 | 168 | 138 | JSON — ships with Python | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.04 | 1.41 | 2.46 | 410 | 270 | JSON | fastest | yes | 90 |
| msgspec-msgpack | 0.21.1 | 1.57 | 2.04 | 3.57 | 339 | 260 | MessagePack | slower | yes | 87 |
| protobuf | 7.35.1 | 2.09 | 2.65 | 4.77 | 367 | 266 | Protocol Buffers | slower | yes | 84 |
| json | python-3.14.0 | 9.90 | 5.33 | 15.3 | 410 | 270 | JSON — ships with Python | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 2.64 | 3.23 | 5.77 | 1190 | 1152 | MessagePack | fastest | yes | 94 |
| protobuf | 7.35.1 | 3.81 | 3.34 | 7.07 | 1061 | 1080 | Protocol Buffers | close | yes | 92 |
| orjson | 3.11.9 | 3.82 | 4.15 | 8.04 | 2407 | 1317 | JSON | slower | yes | 87 |
| json | python-3.14.0 | 50.3 | 28.1 | 79.1 | 2407 | 1317 | JSON — ships with Python | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `orjson`. Small gap: `msgspec-msgpack`. Time/size front: `orjson`, `msgspec-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `msgspec-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: `protobuf`. Time/size front: `msgspec-msgpack`, `protobuf`.

