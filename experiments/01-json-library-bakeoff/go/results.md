# Experiment 1 results — go

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/go/logs/go/2026-08-16-150745.csv`
**Language:** go
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.22 | 1.88 | 3.12 | 448 | — | yes | fastest | yes | 83 |
| segmentio/encoding/json | 0.5.4 | 1.15 | 2.15 | 3.36 | 448 | — | yes | close | yes | 83 |
| sonic | 1.15.2 | 1.18 | 2.30 | 3.49 | 448 | — | yes | close | yes | 80 |
| jsoniter | 1.1.12 | 1.74 | 2.54 | 4.29 | 448 | — | yes | slower | yes | 81 |
| ugorji/json | 1.3.2 | 1.91 | 3.02 | 4.97 | 448 | — | yes | slower | yes | 88 |
| encoding/json | go1.24.13 | 1.46 | 7.50 | 9.00 | 448 | — | yes | slower | yes | 82 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| goccy/go-json | 1.44 | 2.43 | 3.92 | real |
| sonic | 1.45 | 2.98 | 4.41 | real |
| jsoniter | 2.03 | 2.78 | 4.80 | real |
| ugorji/json | 2.46 | 4.01 | 6.45 | real |
| segmentio/encoding/json | 1.24 | 5.44 | 6.71 | real |
| encoding/json | 1.74 | 8.42 | 10.2 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `goccy/go-json`.
**A small gap (a different record could change the order):** `segmentio/encoding/json`, `sonic`.
**Not both slower and larger than another named-JSON library:** `goccy/go-json`.

