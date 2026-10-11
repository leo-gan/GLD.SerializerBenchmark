# Experiment 1 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/01-json-library-bakeoff/zig/logs/zig/2026-10-11-145740.csv`
**Language:** zig
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| serde.json | 1.2.2 | 0.91 | 1.45 | 2.37 | 448 | 233 | yes | fastest | yes | 92 |
| std.json.scanner | 0.16.0 | 0.81 | 2.10 | 2.91 | 448 | 233 | yes | slower | yes | 94 |
| std.json | 0.16.0 | 0.82 | 2.10 | 2.92 | 448 | 233 | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| serde.json | 0.98 | 1.52 | 2.51 | text_on_stream |
| std.json | 0.88 | 2.25 | 3.12 | text_on_stream |
| std.json.scanner | 0.88 | 2.26 | 3.15 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `serde.json`.
**Not both slower and larger than another named-JSON library:** `serde.json`.

