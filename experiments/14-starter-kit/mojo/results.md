# Experiment 14 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/14-starter-kit/mojo/logs/mojo/2026-09-08-155445.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.18 | 1.33 | 1.51 | 118 | 0 | yes | fastest | yes | 89 |
| EmberJson | 0.3.4 | 0.47 | 1.49 | 1.96 | 452 | 0 | yes | slower | yes | 84 |
| mojo-protobuf | 0.6.0 | 0.49 | 1.59 | 2.09 | 157 | 0 | yes | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 0.45 | 3.66 | 4.14 | 329 | 0 | yes | slower | yes | 89 |
| ehsanmok-json | 0.3.0 | 50.8 | 5.39 | 56.3 | 452 | 0 | yes | slower | yes | 89 |
| mojo-toml | 0.9.1 | 20.6 | 49.5 | 70.3 | 489 | 0 | yes | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `mojo-avro`.
**Not both slower and larger than another library in the kit:** `mojo-avro`.

