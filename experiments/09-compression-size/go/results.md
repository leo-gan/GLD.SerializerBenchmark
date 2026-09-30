# Experiment 9 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/go/logs/go/2026-09-29-184523.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.12 | 0.83 | 0.75 | 1.56 | 50 | 75 | Protocol Buffers | fastest | yes | 87 |
| goccy/go-json | 0.10.6 | 0.84 | 1.16 | 2.03 | 168 | 142 | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 0.86 | 1.40 | 2.36 | 128 | 133 | MessagePack | slower | yes | 88 |
| encoding/json | go1.24.13 | 1.02 | 3.28 | 4.36 | 168 | 142 | JSON — ships with Go | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.29 | 2.41 | 3.60 | 411 | 291 | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| vmihailenco/msgpack | 5.4.1 | 1.10 | 2.50 | 3.69 | 346 | 275 | MessagePack | similar | yes | 87 |
| protobuf | 1.36.12 | 1.29 | 2.38 | 3.70 | 368 | 278 | Protocol Buffers | similar | yes | 94 |
| encoding/json | go1.24.13 | 1.67 | 7.52 | 9.25 | 411 | 291 | JSON — ships with Go | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.12 | 2.03 | 2.18 | 4.12 | 1061 | 1084 | Protocol Buffers | fastest | yes | 85 |
| vmihailenco/msgpack | 5.4.1 | 5.10 | 8.14 | 13.6 | 1212 | 1172 | MessagePack | slower | yes | 91 |
| goccy/go-json | 0.10.6 | 12.9 | 15.2 | 27.6 | 2407 | 1227 | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| encoding/json | go1.24.13 | 13.6 | 29.5 | 43.2 | 2407 | 1227 | JSON — ships with Go | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `goccy/go-json`, `vmihailenco/msgpack`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `vmihailenco/msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

