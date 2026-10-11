# Experiment 14 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/14-starter-kit/mojo/logs/mojo/2026-10-11-151330.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 1.08 | 2.87 | 3.97 | 114 | 0 | yes | fastest | yes | 92 |
| mojo-json | 0.5.0 | 1.91 | 3.57 | 5.46 | 448 | 0 | yes | slower | yes | 97 |
| mojo-protobuf | 0.7.0 | 2.26 | 3.08 | 5.63 | 155 | 0 | yes | close | yes | 93 |
| mojo-cbor | 0.8.0 | 1.98 | 5.35 | 7.33 | 332 | 0 | yes | slower | yes | 92 |
| EmberJson | 0.3.4 | 5.35 | 5.26 | 10.6 | 448 | 0 | yes | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 2.97 | 12.3 | 15.2 | 448 | 0 | yes | slower | yes | 93 |
| mojo-toml | 0.9.1 | 31.3 | 69.2 | 102 | 485 | 0 | yes | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `mojo-avro`.
**A small gap (a different record could change the order):** `mojo-protobuf`.
**Not both slower and larger than another library in the kit:** `mojo-avro`.

