# Experiment 14 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/14-starter-kit/kotlin/logs/kotlin/2026-10-11-151326.csv`
**Language:** kotlin
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 23.6 | 24.3 | 48.9 | 440 | 230 | yes | fastest | yes | 88 |
| protobuf | 4.35.0 | 31.3 | 28.0 | 59.9 | 155 | 174 | yes | slower | yes | 86 |
| kotlinx-json | 1.8.1 | 32.2 | 54.8 | 86.8 | 440 | 230 | yes | slower | yes | 81 |
| msgpack | 0.9.8 | 70.2 | 91.3 | 160 | 317 | 227 | yes | slower | yes | 84 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 17.0 | 25.2 | 42.1 | real |
| protobuf | 28.5 | 28.9 | 59.4 | real |
| kotlinx-json | 28.4 | 41.0 | 70.1 | real |
| msgpack | 44.5 | 68.1 | 113 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `moshi-codegen`.
**Not both slower and larger than another library in the kit:** `moshi-codegen`, `protobuf`.

