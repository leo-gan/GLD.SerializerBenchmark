# Experiment 10 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/go/logs/go/2026-09-29-184729.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 0.96 | 1.48 | 2.48 | 257 | 2421 | JSON — fast writer from Experiment 1 | fastest | yes | 91 |
| shamaton/msgpack | 3.2.3 | 1.18 | 1.32 | 2.52 | 199 | 2304 | MessagePack — fast Go writer | similar | yes | 89 |
| protobuf | 1.36.12 | 1.03 | 1.54 | 2.54 | 123 | 2200 | Protocol Buffers | similar | yes | 90 |
| vmihailenco/msgpack | 5.4.1 | 1.31 | 2.43 | 3.74 | 199 | 2318 | MessagePack | slower | yes | 87 |
| encoding/json | go1.24.13 | 1.17 | 4.90 | 6.01 | 257 | 2421 | JSON — ships with Go | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 49.8 | 68.8 | 120 | 25746 | 2421 | JSON — fast writer from Experiment 1 | fastest | yes | 86 |
| protobuf | 1.36.12 | 47.6 | 77.8 | 127 | 12477 | 2200 | Protocol Buffers | close | yes | 85 |
| shamaton/msgpack | 3.2.3 | 64.0 | 75.8 | 140 | 19848 | 2304 | MessagePack — fast Go writer | slower | yes | 93 |
| vmihailenco/msgpack | 5.4.1 | 62.7 | 147 | 211 | 19848 | 2318 | MessagePack | slower | yes | 92 |
| encoding/json | go1.24.13 | 59.5 | 304 | 363 | 25746 | 2421 | JSON — ships with Go | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| shamaton/msgpack | 3.2.3 | 0.56 | 0.73 | 1.30 | 124 | 2304 | MessagePack — fast Go writer | fastest | yes | 82 |
| protobuf | 1.36.12 | 0.75 | 0.70 | 1.44 | 50 | 2200 | Protocol Buffers | close | yes | 83 |
| goccy/go-json | 0.10.6 | 0.68 | 1.00 | 1.69 | 168 | 2421 | JSON — fast writer from Experiment 1 | slower | yes | 78 |
| vmihailenco/msgpack | 5.4.1 | 0.76 | 1.27 | 2.04 | 128 | 2318 | MessagePack | slower | yes | 80 |
| encoding/json | go1.24.13 | 0.78 | 2.98 | 3.78 | 168 | 2421 | JSON — ships with Go | slower | yes | 82 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.12 | 20.9 | 25.3 | 46.4 | 4841 | 2200 | Protocol Buffers | fastest | yes | 94 |
| shamaton/msgpack | 3.2.3 | 26.0 | 29.9 | 57.7 | 12031 | 2304 | MessagePack — fast Go writer | slower | yes | 92 |
| goccy/go-json | 0.10.6 | 32.3 | 42.4 | 74.3 | 16546 | 2421 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 30.7 | 58.4 | 89.6 | 12457 | 2318 | MessagePack | slower | yes | 91 |
| encoding/json | go1.24.13 | 41.9 | 168 | 211 | 16546 | 2421 | JSON — ships with Go | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `goccy/go-json`, `shamaton/msgpack`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `shamaton/msgpack`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `goccy/go-json`. Small gap: `protobuf`. Time/size front: `goccy/go-json`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `shamaton/msgpack`. Small gap: `protobuf`. Time/size front: `shamaton/msgpack`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

