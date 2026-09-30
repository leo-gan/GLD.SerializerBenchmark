# Experiment 14 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/go/logs/go/2026-09-29-185711.csv`
**Language:** go
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 2.07 | 2.90 | 5.09 | 448 | 234 | yes | fastest | yes | 88 |
| protobuf | 1.36.12 | 2.28 | 2.91 | 5.37 | 155 | 179 | yes | similar | yes | 89 |
| vmihailenco/msgpack | 5.4.1 | 3.19 | 4.98 | 8.24 | 405 | 239 | yes | slower | yes | 88 |
| encoding/json | go1.24.13 | 2.79 | 11.1 | 14.1 | 448 | 234 | yes | slower | yes | 95 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf | 1.99 | 2.69 | 4.68 | copied |
| goccy/go-json | 1.69 | 3.21 | 4.89 | real |
| vmihailenco/msgpack | 3.46 | 4.24 | 7.83 | real |
| encoding/json | 2.21 | 10.0 | 12.3 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `goccy/go-json`, `protobuf`.
**Not both slower and larger than another library in the kit:** `goccy/go-json`, `protobuf`.

