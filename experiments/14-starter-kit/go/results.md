# Experiment 14 results — go

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/go/logs/go/2026-08-28-182216.csv`
**Language:** go
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.45 | 2.26 | 3.69 | 448 | 234 | yes | fastest | yes | 89 |
| protobuf | 1.36.11 | 1.82 | 2.42 | 4.26 | 155 | 179 | yes | similar | yes | 94 |
| vmihailenco/msgpack | 5.4.1 | 2.19 | 4.04 | 6.30 | 397 | 242 | yes | slower | yes | 93 |
| encoding/json | go1.24.13 | 1.86 | 8.34 | 10.3 | 448 | 234 | yes | slower | yes | 95 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf | 2.00 | 2.55 | 4.61 | copied |
| goccy/go-json | 1.87 | 3.23 | 4.98 | real |
| vmihailenco/msgpack | 3.37 | 4.40 | 7.73 | real |
| encoding/json | 2.05 | 10.0 | 12.2 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `goccy/go-json`, `protobuf`.
**Not both slower and larger than another library in the kit:** `goccy/go-json`, `protobuf`.

