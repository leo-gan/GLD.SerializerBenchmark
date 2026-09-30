# Experiment 3 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/03-one-language-store/go/logs/go/2026-09-29-184150.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.12 | 0.80 | 0.72 | 1.50 | 50 | 75 | other languages can read — Protocol Buffers | fastest | yes | 89 |
| goccy/go-json | 0.10.6 | 0.81 | 1.11 | 1.94 | 168 | 142 | other languages can read — JSON | slower | yes | 90 |
| encoding/gob | go1.24.13 | 3.14 | 12.3 | 15.9 | 173 | 171 | one language — gob | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 0.96 | 0.86 | 1.80 | copied |
| goccy/go-json | 1 | 0.86 | 1.46 | 2.36 | real |
| encoding/gob | 1 | 3.12 | 12.5 | 15.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

