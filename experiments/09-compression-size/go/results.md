# Experiment 9 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/go/logs/go/2026-08-17-115841.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 0.59 | 0.57 | 1.17 | 50 | 75 | Protocol Buffers | fastest | yes | 91 |
| goccy/go-json | 0.10.6 | 0.61 | 0.82 | 1.39 | 168 | 142 | JSON — fast writer from Experiment 1 | slower | yes | 83 |
| vmihailenco/msgpack | 5.4.1 | 0.64 | 0.99 | 1.60 | 118 | 127 | MessagePack | slower | yes | 85 |
| encoding/json | go1.24.13 | 0.65 | 2.44 | 3.14 | 168 | 142 | JSON — ships with Go | slower | yes | 85 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 0.71 | 1.50 | 2.25 | 368 | 278 | Protocol Buffers | fastest | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 0.69 | 1.55 | 2.25 | 346 | 277 | MessagePack | similar | yes | 87 |
| goccy/go-json | 0.10.6 | 0.74 | 1.53 | 2.31 | 411 | 291 | JSON — fast writer from Experiment 1 | similar | yes | 84 |
| encoding/json | go1.24.13 | 1.09 | 4.91 | 6.02 | 411 | 291 | JSON — ships with Go | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 1.07 | 1.10 | 2.21 | 1061 | 1084 | Protocol Buffers | fastest | yes | 90 |
| vmihailenco/msgpack | 5.4.1 | 3.31 | 5.42 | 8.72 | 1212 | 1173 | MessagePack | slower | yes | 88 |
| goccy/go-json | 0.10.6 | 9.68 | 11.4 | 21.2 | 2407 | 1227 | JSON — fast writer from Experiment 1 | slower | yes | 84 |
| encoding/json | go1.24.13 | 10.3 | 22.9 | 33.2 | 2407 | 1227 | JSON — ships with Go | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `protobuf`, `vmihailenco/msgpack`, `goccy/go-json`. Small gap: —. Time/size front: `protobuf`, `vmihailenco/msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

