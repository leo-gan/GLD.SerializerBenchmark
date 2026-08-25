# Experiment 10 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/go/logs/go/2026-08-17-110645.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 1.08 | 1.26 | 2.33 | 123 | — | Protocol Buffers | fastest | yes | 85 |
| goccy/go-json | 0.10.6 | 1.02 | 1.44 | 2.47 | 257 | — | JSON — fast writer from Experiment 1 | similar | yes | 88 |
| shamaton/msgpack | 3.1.2 | 1.54 | 1.39 | 2.92 | 196 | — | MessagePack — fast Go writer | slower | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 1.30 | 2.54 | 3.92 | 196 | — | MessagePack | slower | yes | 84 |
| encoding/json | go1.24.13 | 1.04 | 4.80 | 5.78 | 257 | — | JSON — ships with Go | slower | yes | 84 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 47.6 | 64.0 | 113 | 25746 | — | JSON — fast writer from Experiment 1 | fastest | yes | 87 |
| protobuf | 1.36.11 | 46.2 | 79.1 | 126 | 12477 | — | Protocol Buffers | slower | yes | 91 |
| shamaton/msgpack | 3.1.2 | 63.9 | 74.0 | 138 | 19548 | — | MessagePack — fast Go writer | slower | yes | 90 |
| vmihailenco/msgpack | 5.4.1 | 63.8 | 149 | 215 | 19548 | — | MessagePack | slower | yes | 89 |
| encoding/json | go1.24.13 | 58.5 | 301 | 359 | 25746 | — | JSON — ships with Go | slower | yes | 87 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 1.35 | 1.04 | 2.36 | 50 | — | Protocol Buffers | fastest | yes | 92 |
| shamaton/msgpack | 3.1.2 | 1.55 | 1.49 | 3.14 | 114 | — | MessagePack — fast Go writer | close | yes | 92 |
| goccy/go-json | 0.10.6 | 1.40 | 1.92 | 3.46 | 168 | — | JSON — fast writer from Experiment 1 | close | yes | 88 |
| vmihailenco/msgpack | 5.4.1 | 1.53 | 2.40 | 3.91 | 118 | — | MessagePack | slower | yes | 91 |
| encoding/json | go1.24.13 | 1.32 | 4.81 | 6.09 | 168 | — | JSON — ships with Go | slower | yes | 88 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 19.4 | 23.8 | 43.6 | 4841 | — | Protocol Buffers | fastest | yes | 91 |
| shamaton/msgpack | 3.1.2 | 24.0 | 29.3 | 52.7 | 11031 | — | MessagePack — fast Go writer | slower | yes | 92 |
| goccy/go-json | 0.10.6 | 28.3 | 39.5 | 69.4 | 16546 | — | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| vmihailenco/msgpack | 5.4.1 | 26.3 | 50.6 | 76.4 | 11457 | — | MessagePack | slower | yes | 87 |
| encoding/json | go1.24.13 | 36.7 | 164 | 200 | 16546 | — | JSON — ships with Go | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `protobuf`, `goccy/go-json`. Small gap: —. Time/size front: `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: `shamaton/msgpack`, `goccy/go-json`. Time/size front: `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

