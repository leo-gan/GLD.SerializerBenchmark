# Experiment 11 results — go

**Date:** 2026-11-12
**Raw file:** `experiments/03-memory-vs-stream/go/logs/go/2026-11-12-163838.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 2.01 | 2.76 | 4.82 | 448 | 233 | JSON | fastest | yes | 85 |
| protobuf | 1.36.12 | 2.35 | 2.58 | 4.98 | 155 | 180 | Protocol Buffers | similar | yes | 90 |
| vmihailenco/msgpack | 5.4.1 | 2.77 | 4.73 | 7.51 | 405 | 235 | MessagePack | slower | yes | 90 |
| encoding/json | go1.27.1 | 3.15 | 6.05 | 9.29 | 448 | 233 | JSON — stdlib | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 1.70 | 3.41 | 5.10 | real |
| vmihailenco/msgpack | 1 | 3.72 | 5.14 | 8.99 | real |
| encoding/json | 1 | 3.94 | 8.54 | 12.7 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `protobuf`.

