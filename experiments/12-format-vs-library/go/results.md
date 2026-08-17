# Experiment 12 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/12-format-vs-library/go/logs/go/2026-08-17-103202.csv`
**Language:** go
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.14 | 1.78 | 2.89 | 448 | — | JSON — another library (Experiment 1) | fastest | yes | 84 |
| ugorji/msgpack | 1.3.2 | 1.37 | 2.30 | 3.68 | 329 | — | ugorji — MessagePack | slower | yes | 91 |
| shamaton/msgpack | 3.1.2 | 2.01 | 1.71 | 3.71 | 317 | — | MessagePack — another library | slower | yes | 92 |
| ugorji/cbor | 1.3.2 | 1.59 | 2.43 | 4.02 | 332 | — | ugorji — CBOR | slower | yes | 92 |
| ugorji/json | 1.3.2 | 1.83 | 2.96 | 4.84 | 448 | — | ugorji — JSON | slower | yes | 92 |
| vmihailenco/msgpack | 5.4.1 | 1.80 | 3.28 | 5.06 | 397 | — | MessagePack — another library | slower | yes | 85 |
| encoding/json | go1.24.13 | 1.40 | 7.21 | 8.66 | 448 | — | JSON — ships with Go | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 1.46 | 2.73 | 4.24 | real |
| ugorji/msgpack | 1 | 1.83 | 2.99 | 4.81 | real |
| ugorji/cbor | 1 | 1.85 | 3.35 | 5.29 | real |
| shamaton/msgpack | 1 | 2.16 | 3.75 | 5.95 | real |
| ugorji/json | 1 | 2.64 | 4.37 | 6.98 | real |
| vmihailenco/msgpack | 1 | 3.15 | 3.93 | 7.11 | real |
| encoding/json | 1 | 1.79 | 8.97 | 10.9 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `ugorji/msgpack`, `shamaton/msgpack`.

