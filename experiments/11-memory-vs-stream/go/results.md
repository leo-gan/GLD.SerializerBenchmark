# Experiment 11 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/11-memory-vs-stream/go/logs/go/2026-08-17-110922.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.58 | 2.38 | 4.11 | 448 | — | JSON | fastest | yes | 88 |
| protobuf | 1.36.11 | 1.85 | 2.26 | 4.13 | 155 | — | Protocol Buffers | similar | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 2.36 | 4.30 | 6.71 | 397 | — | MessagePack | slower | yes | 84 |
| encoding/json | go1.24.13 | 1.81 | 9.26 | 11.2 | 448 | — | JSON — stdlib | slower | yes | 82 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 1.73 | 2.26 | 3.99 | copied |
| goccy/go-json | 1 | 1.55 | 2.88 | 4.42 | real |
| vmihailenco/msgpack | 1 | 3.16 | 4.03 | 7.24 | real |
| encoding/json | 1 | 1.81 | 9.30 | 11.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `protobuf`.

