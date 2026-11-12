# Experiment 9 results — go

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/go/logs/go/2026-11-12-163751.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.68 | 0.85 | 1.56 | 57 | 82 | positional binary — no field names | fastest | yes | 94 |
| protobuf | 1.36.12 | 1.28 | 0.93 | 2.16 | 50 | 75 | Protocol Buffers | slower | yes | 96 |
| goccy/go-json | 0.10.6 | 1.16 | 1.67 | 2.81 | 168 | 138 | JSON — fast writer fast named JSON | slower | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 1.38 | 2.06 | 3.51 | 128 | 130 | MessagePack | slower | yes | 92 |
| encoding/json | go1.27.1 | 1.44 | 2.83 | 4.32 | 168 | 138 | JSON — ships with Go | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.62 | 2.29 | 2.98 | 436 | 300 | positional binary — no field names | fastest | yes | 90 |
| goccy/go-json | 0.10.6 | 1.48 | 2.09 | 3.73 | 411 | 288 | JSON — fast writer fast named JSON | slower | yes | 87 |
| vmihailenco/msgpack | 5.4.1 | 1.45 | 2.60 | 4.01 | 346 | 371 | MessagePack | slower | yes | 88 |
| protobuf | 1.36.12 | 1.55 | 2.35 | 4.03 | 368 | 393 | Protocol Buffers | slower | yes | 86 |
| encoding/json | go1.27.1 | 1.91 | 4.09 | 6.14 | 411 | 288 | JSON — ships with Go | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.81 | 1.64 | 2.44 | 1073 | 1089 | positional binary — no field names | fastest | yes | 87 |
| protobuf | 1.36.12 | 1.58 | 1.52 | 3.10 | 1061 | 1086 | Protocol Buffers | slower | yes | 88 |
| vmihailenco/msgpack | 5.4.1 | 4.28 | 6.26 | 10.6 | 1212 | 1237 | MessagePack | slower | yes | 86 |
| goccy/go-json | 0.10.6 | 8.03 | 13.2 | 21.3 | 2407 | 1226 | JSON — fast writer fast named JSON | slower | yes | 90 |
| encoding/json | go1.27.1 | 8.37 | 17.9 | 26.4 | 2407 | 1226 | JSON — ships with Go | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 0.45 | 0.89 | 1.35 | real |
| vmihailenco/msgpack | 1 | 0.69 | 1.06 | 1.73 | real |
| encoding/json | 1 | 0.99 | 2.11 | 3.06 | real |
| goccy/go-json | 1 | 0.74 | 1.59 | 2.32 | real |
| vmihailenco/msgpack | 1 | 1.07 | 1.65 | 2.75 | real |
| encoding/json | 1 | 1.40 | 3.35 | 4.77 | real |
| vmihailenco/msgpack | 1 | 3.99 | 5.65 | 9.65 | real |
| goccy/go-json | 1 | 7.00 | 14.2 | 21.2 | real |
| encoding/json | 1 | 8.05 | 21.8 | 30.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `goccy/go-json`, `vmihailenco/msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `protobuf`.

