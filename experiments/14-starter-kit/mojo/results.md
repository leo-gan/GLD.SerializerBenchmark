# Experiment 14 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/14-starter-kit/mojo/logs/mojo/2026-09-23-181654.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.22 | 1.53 | 1.75 | 118 | 0 | yes | fastest | yes | 83 |
| mojo-json | 0.3.0 | 0.60 | 1.19 | 1.80 | 452 | 0 | yes | slower | yes | 79 |
| EmberJson | 0.3.4 | 0.56 | 1.70 | 2.28 | 452 | 0 | yes | slower | yes | 87 |
| mojo-protobuf | 0.6.0 | 0.59 | 1.84 | 2.42 | 157 | 0 | yes | slower | yes | 77 |
| mojo-cbor | 0.6.0 | 0.53 | 4.28 | 4.81 | 329 | 0 | yes | slower | yes | 72 |
| ehsanmok-json | 0.4.0 | 0.77 | 7.27 | 8.05 | 452 | 0 | yes | slower | yes | 80 |
| mojo-toml | 0.9.1 | 23.4 | 57.4 | 80.8 | 489 | 0 | yes | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `mojo-avro`.
**Not both slower and larger than another library in the kit:** `mojo-avro`.

