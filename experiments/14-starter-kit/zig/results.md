# Experiment 14 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/14-starter-kit/zig/logs/zig/2026-10-11-151324.csv`
**Language:** zig
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| serde.msgpack | 1.2.2 | 0.50 | 0.69 | 1.19 | 325 | 230 | yes | fastest | yes | 94 |
| protobuf | 5.0.0 | 0.68 | 0.67 | 1.36 | 155 | 176 | yes | slower | yes | 94 |
| serde.json | 1.2.2 | 0.98 | 1.56 | 2.54 | 448 | 233 | yes | slower | yes | 95 |
| std.json | 0.16.0 | 0.87 | 2.27 | 3.15 | 448 | 233 | yes | slower | yes | 93 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| serde.msgpack | 0.50 | 0.65 | 1.15 | copied |
| protobuf | 0.70 | 0.66 | 1.36 | copied |
| serde.json | 0.98 | 1.52 | 2.50 | text_on_stream |
| std.json | 0.88 | 2.28 | 3.15 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `serde.msgpack`.
**Not both slower and larger than another library in the kit:** `serde.msgpack`, `protobuf`.

