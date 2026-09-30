# Experiment 10 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/python/logs/python/2026-09-29-184653.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.85 | 1.99 | 3.78 | 112 | 2020 | MessagePack — msgspec | fastest | yes | 95 |
| orjson | 3.12.0 | 1.92 | 2.46 | 4.35 | 257 | 2492 | JSON — fast writer from Experiment 1 | similar | yes | 91 |
| protobuf | 7.36.1 | 3.05 | 2.99 | 6.20 | 123 | 2150 | Protocol Buffers | slower | yes | 96 |
| msgpack | 1.2.2 | 3.63 | 4.53 | 8.05 | 199 | 2303 | MessagePack | slower | yes | 98 |
| json | python-3.14.0 | 11.6 | 8.69 | 20.4 | 257 | 2492 | JSON — ships with Python | slower | yes | 96 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.36.1 | 31.4 | 38.0 | 69.3 | 12477 | 2150 | Protocol Buffers | fastest | yes | 87 |
| msgspec-msgpack | 0.21.1 | 33.5 | 51.6 | 85.1 | 11148 | 2020 | MessagePack — msgspec | slower | yes | 83 |
| orjson | 3.12.0 | 61.1 | 81.3 | 143 | 25746 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| msgpack | 1.2.2 | 88.8 | 107 | 197 | 19848 | 2303 | MessagePack | slower | yes | 85 |
| json | python-3.14.0 | 214 | 143 | 357 | 25746 | 2492 | JSON — ships with Python | slower | yes | 81 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.05 | 1.21 | 2.26 | 52 | 2020 | MessagePack — msgspec | fastest | yes | 85 |
| orjson | 3.12.0 | 1.23 | 1.71 | 2.99 | 168 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 94 |
| protobuf | 7.36.1 | 2.55 | 2.23 | 4.75 | 50 | 2150 | Protocol Buffers | slower | yes | 84 |
| msgpack | 1.2.2 | 2.55 | 3.49 | 6.01 | 124 | 2303 | MessagePack | slower | yes | 90 |
| json | python-3.14.0 | 9.98 | 7.65 | 17.6 | 168 | 2492 | JSON — ships with Python | slower | yes | 90 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 11.3 | 19.5 | 30.8 | 4831 | 2020 | MessagePack — msgspec | fastest | yes | 89 |
| protobuf | 7.36.1 | 17.7 | 16.9 | 34.3 | 4841 | 2150 | Protocol Buffers | slower | yes | 85 |
| orjson | 3.12.0 | 20.1 | 43.6 | 63.4 | 16546 | 2492 | JSON — fast writer from Experiment 1 | slower | yes | 97 |
| msgpack | 1.2.2 | 49.0 | 66.6 | 116 | 12031 | 2303 | MessagePack | slower | yes | 89 |
| json | python-3.14.0 | 129 | 116 | 244 | 16546 | 2492 | JSON — ships with Python | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `msgspec-msgpack`, `orjson`. Small gap: —. Time/size front: `msgspec-msgpack`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `msgspec-msgpack`.

**sample B (flat), N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`.

