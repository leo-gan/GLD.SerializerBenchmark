# Experiment 11 results — go

**Date:** 2026-11-12
**Raw file:** `experiments/03-memory-vs-stream/go/logs/go/2026-11-12-122327.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.85 | 2.59 | 4.49 | 448 | 233 | JSON | fastest | yes | 83 |
| protobuf | 1.36.12 | 2.29 | 2.43 | 4.68 | 155 | 180 | Protocol Buffers | similar | yes | 87 |
| vmihailenco/msgpack | 5.4.1 | 2.70 | 4.43 | 7.09 | 405 | 235 | MessagePack | slower | yes | 91 |
| encoding/json | go1.27.1 | 2.90 | 5.89 | 9.01 | 448 | 233 | JSON — stdlib | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 0.75 | 1.80 | 2.54 | real |
| vmihailenco/msgpack | 1 | 2.11 | 2.90 | 4.99 | real |
| encoding/json | 1 | 1.98 | 4.73 | 6.74 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `protobuf`.

