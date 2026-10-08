# Experiment 12 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/12-format-vs-library/go/logs/go/2026-09-29-184750.csv`
**Language:** go
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.52 | 2.30 | 3.90 | 448 | 234 | JSON — another library (Experiment 1) | fastest | yes | 89 |
| shamaton/msgpack | 3.2.3 | 2.19 | 2.12 | 4.38 | 325 | 231 | MessagePack — another library | close | yes | 86 |
| ugorji/msgpack | 1.3.2 | 1.89 | 2.98 | 4.90 | 329 | 233 | ugorji — MessagePack | slower | yes | 84 |
| ugorji/cbor | 1.3.2 | 1.98 | 3.17 | 5.21 | 332 | 221 | ugorji — CBOR | slower | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 2.45 | 4.07 | 6.57 | 405 | 239 | MessagePack — another library | slower | yes | 87 |
| ugorji/json | 1.3.2 | 2.61 | 4.10 | 6.71 | 448 | 234 | ugorji — JSON | slower | yes | 85 |
| encoding/json | go1.24.13 | 1.99 | 8.95 | 11.0 | 448 | 234 | JSON — ships with Go | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1 | 1.86 | 3.47 | 5.37 | real |
| ugorji/msgpack | 1 | 2.25 | 3.60 | 5.94 | real |
| ugorji/cbor | 1 | 2.36 | 3.95 | 6.33 | real |
| shamaton/msgpack | 1 | 2.15 | 4.50 | 6.58 | real |
| vmihailenco/msgpack | 1 | 3.53 | 4.50 | 8.06 | real |
| ugorji/json | 1 | 3.22 | 5.07 | 8.38 | real |
| encoding/json | 1 | 2.32 | 10.3 | 12.7 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: `shamaton/msgpack`. Time/size front: `goccy/go-json`, `shamaton/msgpack`.

