# Experiment 1 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/01-json-library-bakeoff/zig/logs/zig/2026-08-28-173400.csv`
**Language:** zig
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| serde.json | 1.0.7 | 1.14 | 1.50 | 2.61 | 448 | 233 | yes | fastest | yes | 83 |
| std.json.scanner | 0.16.0 | 1.06 | 2.64 | 3.70 | 448 | 233 | yes | slower | yes | 85 |
| std.json | 0.16.0 | 1.10 | 2.62 | 3.70 | 448 | 233 | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| serde.json | 1.24 | 1.65 | 2.88 | copied |
| std.json.scanner | 1.20 | 2.94 | 4.13 | text_on_stream |
| std.json | 1.20 | 2.97 | 4.17 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `serde.json`.
**Not both slower and larger than another named-JSON library:** `serde.json`.

