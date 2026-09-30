# Experiment 11 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/11-memory-vs-stream/go/logs/go/2026-09-29-184737.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.79 | 2.70 | 4.70 | 448 | 234 | JSON | fastest | yes | 84 |
| protobuf | 1.36.12 | 2.27 | 2.84 | 5.30 | 155 | 179 | Protocol Buffers | similar | yes | 92 |
| vmihailenco/msgpack | 5.4.1 | 2.94 | 4.65 | 7.72 | 405 | 239 | MessagePack | slower | yes | 89 |
| encoding/json | go1.24.13 | 2.41 | 10.0 | 12.2 | 448 | 234 | JSON — stdlib | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 1.94 | 2.63 | 4.62 | copied |
| goccy/go-json | 1 | 1.68 | 3.09 | 4.74 | real |
| vmihailenco/msgpack | 1 | 3.35 | 4.26 | 7.65 | real |
| encoding/json | 1 | 2.15 | 10.2 | 12.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`, `protobuf`. Small gap: —. Time/size front: `goccy/go-json`, `protobuf`.

