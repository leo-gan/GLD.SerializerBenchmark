# Experiment 14 results — kotlin

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/kotlin/logs/kotlin/2026-08-28-182227.csv`
**Language:** kotlin
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 27.1 | 28.7 | 57.1 | 440 | 230 | yes | fastest | yes | 94 |
| protobuf | 4.28.3 | 34.3 | 30.1 | 66.1 | 155 | 174 | yes | similar | yes | 90 |
| kotlinx-json | 1.8.1 | 40.0 | 63.8 | 104 | 440 | 230 | yes | slower | yes | 90 |
| msgpack | 0.9.8 | 81.7 | 100 | 181 | 317 | 227 | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 15.1 | 19.8 | 36.1 | real |
| protobuf | 24.0 | 25.6 | 49.4 | real |
| kotlinx-json | 25.6 | 39.5 | 65.2 | real |
| msgpack | 45.7 | 57.3 | 105 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `moshi-codegen`, `protobuf`.
**Not both slower and larger than another library in the kit:** `moshi-codegen`, `protobuf`.

