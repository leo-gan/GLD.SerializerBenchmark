# Experiment 1 results — swift

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/swift/logs/swift/2026-08-16-150620.csv`
**Language:** swift
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 20.2 | 33.9 | 54.4 | 448 | — | yes | fastest | yes | 79 |
| Foundation.JSONEncoder | Foundation | 23.1 | 33.0 | 55.7 | 448 | — | yes | slower | yes | 81 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| IkigaJSON | 53.3 | 35.3 | 88.7 | copied |
| Foundation.JSONEncoder | 57.8 | 33.0 | 90.8 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `IkigaJSON`.
**Not both slower and larger than another named-JSON library:** `IkigaJSON`.

