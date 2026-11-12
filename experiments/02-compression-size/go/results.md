# Experiment 9 results — go

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/go/logs/go/2026-11-12-100810.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.53 | 0.73 | 1.26 | 57 | 82 | positional binary — no field names | fastest | yes | 85 |
| protobuf | 1.36.12 | 1.04 | 0.88 | 1.90 | 50 | 75 | Protocol Buffers | slower | yes | 92 |
| goccy/go-json | 0.10.6 | 0.95 | 1.33 | 2.28 | 168 | 138 | JSON — fast writer fast named JSON | slower | yes | 81 |
| vmihailenco/msgpack | 5.4.1 | 1.02 | 1.66 | 2.69 | 128 | 130 | MessagePack | slower | yes | 84 |
| encoding/json | go1.27.1 | 1.17 | 2.17 | 3.31 | 168 | 138 | JSON — ships with Go | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.54 | 2.01 | 2.57 | 436 | 300 | positional binary — no field names | fastest | yes | 81 |
| goccy/go-json | 0.10.6 | 1.32 | 1.84 | 3.19 | 411 | 288 | JSON — fast writer fast named JSON | slower | yes | 73 |
| vmihailenco/msgpack | 5.4.1 | 1.11 | 2.37 | 3.47 | 346 | 371 | MessagePack | slower | yes | 83 |
| protobuf | 1.36.12 | 1.39 | 2.12 | 3.52 | 368 | 393 | Protocol Buffers | slower | yes | 77 |
| encoding/json | go1.27.1 | 1.61 | 3.27 | 4.84 | 411 | 288 | JSON — ships with Go | slower | yes | 82 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.91 | 1.72 | 2.56 | 1073 | 1089 | positional binary — no field names | fastest | yes | 87 |
| protobuf | 1.36.12 | 1.64 | 1.58 | 3.11 | 1061 | 1086 | Protocol Buffers | slower | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 4.44 | 6.47 | 11.1 | 1212 | 1237 | MessagePack | slower | yes | 89 |
| goccy/go-json | 0.10.6 | 8.44 | 13.8 | 22.2 | 2407 | 1226 | JSON — fast writer fast named JSON | slower | yes | 88 |
| encoding/json | go1.27.1 | 8.05 | 17.2 | 25.4 | 2407 | 1226 | JSON — ships with Go | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 0.44 | 0.85 | 1.29 | real |
| vmihailenco/msgpack | 1 | 0.75 | 0.97 | 1.72 | real |
| encoding/json | 1 | 1.07 | 2.07 | 3.22 | real |
| goccy/go-json | 1 | 0.73 | 1.60 | 2.49 | real |
| vmihailenco/msgpack | 1 | 1.06 | 1.66 | 2.81 | real |
| encoding/json | 1 | 1.53 | 3.69 | 5.20 | real |
| vmihailenco/msgpack | 1 | 4.39 | 6.19 | 10.5 | real |
| goccy/go-json | 1 | 8.57 | 17.1 | 24.6 | real |
| encoding/json | 1 | 9.15 | 26.3 | 35.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `goccy/go-json`, `vmihailenco/msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

