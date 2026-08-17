# Experiment 10 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/python/logs/python/2026-08-17-110630.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.10 | 1.61 | 2.74 | 257 | 2492 | JSON — fast writer from Experiment 1 | fastest | yes | 91 |
| msgspec-msgpack | 0.21.1 | 1.41 | 1.74 | 3.16 | 112 | 2020 | MessagePack — msgspec | slower | yes | 88 |
| protobuf | 7.35.1 | 2.11 | 2.24 | 4.44 | 123 | 2150 | Protocol Buffers | slower | yes | 85 |
| msgpack | 1.2.1 | 2.53 | 3.36 | 5.92 | 199 | 2303 | MessagePack | slower | yes | 83 |
| json | python-3.14.0 | 9.62 | 5.81 | 15.3 | 257 | 2492 | JSON — ships with Python | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.35.1 | 32.2 | 38.8 | 70.2 | 12477 | 2150 | Protocol Buffers | fastest | yes | 96 |
| msgspec-msgpack | 0.21.1 | 35.2 | 53.6 | 89.0 | 11148 | 2020 | MessagePack — msgspec | slower | yes | 92 |
| orjson | 3.11.9 | 47.1 | 82.1 | 134 | 25746 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| msgpack | 1.2.1 | 94.1 | 112 | 206 | 19848 | 2303 | MessagePack | slower | yes | 92 |
| json | python-3.14.0 | 199 | 148 | 347 | 25746 | 2492 | JSON — ships with Python | slower | yes | 93 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 0.72 | 1.02 | 1.72 | 168 | 2492 | JSON — fast writer from Experiment 1 | fastest | yes | 93 |
| msgspec-msgpack | 0.21.1 | 0.86 | 1.07 | 1.93 | 52 | 2020 | MessagePack — msgspec | close | yes | 89 |
| protobuf | 7.35.1 | 1.74 | 1.59 | 3.36 | 50 | 2150 | Protocol Buffers | slower | yes | 86 |
| msgpack | 1.2.1 | 1.92 | 2.41 | 4.38 | 124 | 2303 | MessagePack | slower | yes | 91 |
| json | python-3.14.0 | 7.50 | 4.65 | 12.2 | 168 | 2492 | JSON — ships with Python | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 12.5 | 21.2 | 33.5 | 4831 | 2020 | MessagePack — msgspec | fastest | yes | 93 |
| protobuf | 7.35.1 | 19.1 | 17.1 | 37.2 | 4841 | 2150 | Protocol Buffers | slower | yes | 96 |
| orjson | 3.11.9 | 20.6 | 41.8 | 64.6 | 16546 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 95 |
| msgpack | 1.2.1 | 51.0 | 65.3 | 117 | 12031 | 2303 | MessagePack | slower | yes | 95 |
| json | python-3.14.0 | 133 | 118 | 251 | 16546 | 2492 | JSON — ships with Python | slower | yes | 97 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `msgspec-msgpack`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `msgspec-msgpack`.

**sample B (flat), N = 1, memory** — not clearly slower: `orjson`. Small gap: `msgspec-msgpack`. Time/size front: `orjson`, `msgspec-msgpack`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`.

