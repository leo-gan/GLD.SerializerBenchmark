# Experiment 1 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/01-json-library-bakeoff/mojo/logs/mojo/2026-09-23-181427.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.65 | 1.29 | 1.93 | 452 | 0 | yes | fastest | yes | 93 |
| EmberJson | 0.3.4 | 0.56 | 1.74 | 2.32 | 452 | 0 | yes | slower | yes | 82 |
| ehsanmok-json | 0.4.0 | 0.79 | 7.55 | 8.40 | 452 | 0 | yes | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `mojo-json`.
**Not both slower and larger than another named-JSON library:** `mojo-json`.

