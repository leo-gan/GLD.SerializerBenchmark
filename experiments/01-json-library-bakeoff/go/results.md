# Experiment 1 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/go/logs/go/2026-09-29-184050.csv`
**Language:** go
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.71 | 2.60 | 4.26 | 448 | 234 | yes | fastest | yes | 92 |
| segmentio/encoding/json | 0.5.4 | 1.36 | 3.00 | 4.45 | 448 | 234 | yes | similar | yes | 93 |
| sonic | 1.15.4 | 1.49 | 2.96 | 4.51 | 448 | 234 | yes | similar | yes | 85 |
| jsoniter | 1.1.12 | 2.37 | 3.16 | 5.56 | 448 | 234 | yes | slower | yes | 92 |
| ugorji/json | 1.3.2 | 2.67 | 4.23 | 7.00 | 448 | 234 | yes | slower | yes | 89 |
| encoding/json | go1.24.13 | 2.11 | 9.42 | 11.6 | 448 | 234 | yes | slower | yes | 94 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1.61 | 3.19 | 4.83 | real |
| sonic | 1.69 | 3.55 | 5.28 | real |
| jsoniter | 2.56 | 3.35 | 5.83 | real |
| ugorji/json | 3.06 | 4.58 | 7.61 | real |
| segmentio/encoding/json | 1.32 | 6.84 | 8.06 | real |
| encoding/json | 2.09 | 9.89 | 12.1 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `goccy/go-json`, `segmentio/encoding/json`, `sonic`.
**Not both slower and larger than another named-JSON library:** `goccy/go-json`.

