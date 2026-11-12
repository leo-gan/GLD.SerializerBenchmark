# Experiment 9 results — go

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/go/logs/go/2026-11-12-122321.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.53 | 0.67 | 1.22 | 57 | 82 | positional binary — no field names | fastest | yes | 89 |
| protobuf | 1.36.12 | 1.06 | 0.84 | 1.90 | 50 | 75 | Protocol Buffers | slower | yes | 86 |
| goccy/go-json | 0.10.6 | 1.07 | 1.39 | 2.46 | 168 | 138 | JSON — fast writer fast named JSON | slower | yes | 81 |
| vmihailenco/msgpack | 5.4.1 | 1.18 | 1.78 | 2.93 | 128 | 130 | MessagePack | slower | yes | 84 |
| encoding/json | go1.27.1 | 1.13 | 2.30 | 3.50 | 168 | 138 | JSON — ships with Go | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.55 | 2.06 | 2.63 | 436 | 300 | positional binary — no field names | fastest | yes | 80 |
| goccy/go-json | 0.10.6 | 1.24 | 1.78 | 3.07 | 411 | 288 | JSON — fast writer fast named JSON | slower | yes | 78 |
| vmihailenco/msgpack | 5.4.1 | 1.17 | 2.23 | 3.47 | 346 | 371 | MessagePack | slower | yes | 79 |
| protobuf | 1.36.12 | 1.43 | 2.08 | 3.54 | 368 | 393 | Protocol Buffers | slower | yes | 77 |
| encoding/json | go1.27.1 | 1.62 | 3.49 | 5.20 | 411 | 288 | JSON — ships with Go | slower | yes | 82 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.68 | 1.58 | 2.25 | 1073 | 1089 | positional binary — no field names | fastest | yes | 86 |
| protobuf | 1.36.12 | 1.46 | 1.37 | 2.86 | 1061 | 1086 | Protocol Buffers | slower | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 3.82 | 6.04 | 9.78 | 1212 | 1237 | MessagePack | slower | yes | 84 |
| goccy/go-json | 0.10.6 | 7.77 | 12.9 | 20.5 | 2407 | 1226 | JSON — fast writer fast named JSON | slower | yes | 89 |
| encoding/json | go1.27.1 | 7.90 | 17.7 | 25.6 | 2407 | 1226 | JSON — ships with Go | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 0.43 | 0.83 | 1.25 | real |
| vmihailenco/msgpack | 1 | 0.65 | 0.98 | 1.65 | real |
| encoding/json | 1 | 0.92 | 1.95 | 2.91 | real |
| goccy/go-json | 1 | 1.06 | 2.24 | 3.10 | real |
| vmihailenco/msgpack | 1 | 1.49 | 1.93 | 3.55 | real |
| encoding/json | 1 | 2.25 | 5.35 | 7.58 | real |
| vmihailenco/msgpack | 1 | 3.45 | 4.87 | 8.37 | real |
| goccy/go-json | 1 | 6.27 | 12.7 | 18.9 | real |
| encoding/json | 1 | 7.15 | 19.5 | 26.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `goccy/go-json`, `vmihailenco/msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

