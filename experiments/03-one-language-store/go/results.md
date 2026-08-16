# Experiment 3 results — go

**Date:** 2026-08-16
**Raw file:** `experiments/03-one-language-store/go/logs/go/2026-08-16-160023.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 0.65 | 0.45 | 1.10 | 50 | — | other languages can read — Protocol Buffers | fastest | yes | 86 |
| goccy/go-json | 0.10.6 | 0.72 | 0.92 | 1.70 | 168 | — | other languages can read — JSON | slower | yes | 88 |
| encoding/gob | go1.24.13 | 2.74 | 12.0 | 14.6 | 173 | — | one language — gob | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 0.74 | 0.57 | 1.31 | copied |
| goccy/go-json | 1 | 0.85 | 1.12 | 1.95 | real |
| encoding/gob | 1 | 2.62 | 11.0 | 13.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

