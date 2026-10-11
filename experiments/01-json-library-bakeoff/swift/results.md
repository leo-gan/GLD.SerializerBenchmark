# Experiment 1 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/01-json-library-bakeoff/swift/logs/swift/2026-10-11-145715.csv`
**Language:** swift
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 18.2 | 32.0 | 50.2 | 448 | 229 | yes | fastest | yes | 75 |
| Foundation.JSONEncoder | Foundation | 21.9 | 29.7 | 51.6 | 448 | 232 | yes | slower | yes | 83 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| IkigaJSON | 49.6 | 33.6 | 83.3 | copied |
| Foundation.JSONEncoder | 53.4 | 31.2 | 84.7 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `IkigaJSON`.
**Not both slower and larger than another named-JSON library:** `IkigaJSON`.

