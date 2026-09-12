# Experiment 14 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/14-starter-kit/mojo/logs/mojo/2026-09-12-132756.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.39 | 1.59 | 118 | 0 | yes | fastest | yes | 90 |
| mojo-json | 0.3.0 | 0.55 | 1.09 | 1.64 | 452 | 0 | yes | slower | yes | 87 |
| EmberJson | 0.3.4 | 0.49 | 1.55 | 2.05 | 452 | 0 | yes | slower | yes | 94 |
| mojo-protobuf | 0.6.0 | 0.51 | 1.66 | 2.18 | 157 | 0 | yes | slower | yes | 83 |
| mojo-cbor | 0.6.0 | 0.47 | 3.87 | 4.35 | 329 | 0 | yes | slower | yes | 78 |
| ehsanmok-json | 0.3.1 | 0.69 | 6.30 | 6.99 | 452 | 0 | yes | slower | yes | 78 |
| mojo-toml | 0.9.1 | 21.2 | 51.2 | 72.4 | 489 | 0 | yes | slower | yes | 80 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `mojo-avro`.
**Not both slower and larger than another library in the kit:** `mojo-avro`.

