# Experiment 14 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/14-starter-kit/mojo/logs/mojo/2026-09-09-132227.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.44 | 1.64 | 118 | 0 | yes | fastest | yes | 83 |
| EmberJson | 0.3.4 | 0.52 | 1.62 | 2.14 | 452 | 0 | yes | slower | yes | 83 |
| mojo-protobuf | 0.6.0 | 0.61 | 1.70 | 2.33 | 157 | 0 | yes | slower | yes | 83 |
| mojo-cbor | 0.6.0 | 0.50 | 4.03 | 4.53 | 329 | 0 | yes | slower | yes | 83 |
| mojo-json | 0.2.0 | 2.28 | 2.94 | 5.23 | 452 | 0 | yes | slower | yes | 82 |
| ehsanmok-json | 0.3.0 | 55.8 | 6.03 | 62.0 | 452 | 0 | yes | slower | yes | 85 |
| mojo-toml | 0.9.1 | 22.3 | 53.7 | 76.0 | 489 | 0 | yes | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `mojo-avro`.
**Not both slower and larger than another library in the kit:** `mojo-avro`.

