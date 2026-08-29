# Experiment 14 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/zig/logs/zig/2026-08-28-182347.csv`
**Language:** zig
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| protobuf | 5.0.0 | 0.61 | 0.52 | 1.14 | 155 | 176 | yes | fastest | yes | 85 |
| serde.msgpack | 1.0.7 | 1.05 | 0.63 | 1.67 | 325 | 230 | yes | slower | yes | 88 |
| serde.json | 1.0.7 | 0.98 | 1.43 | 2.42 | 448 | 233 | yes | slower | yes | 88 |
| std.json | 0.16.0 | 1.02 | 2.41 | 3.42 | 448 | 233 | yes | slower | yes | 91 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf | 0.66 | 0.60 | 1.26 | copied |
| serde.msgpack | 1.18 | 0.72 | 1.89 | copied |
| serde.json | 1.09 | 1.59 | 2.71 | copied |
| std.json | 1.16 | 2.74 | 3.91 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `protobuf`.
**Not both slower and larger than another library in the kit:** `protobuf`.

