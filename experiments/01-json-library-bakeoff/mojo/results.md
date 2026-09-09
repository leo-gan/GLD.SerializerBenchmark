# Experiment 1 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/01-json-library-bakeoff/mojo/logs/mojo/2026-09-09-132053.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.47 | 1.46 | 1.92 | 452 | 0 | yes | fastest | yes | 94 |
| mojo-json | 0.2.0 | 2.05 | 2.61 | 4.65 | 452 | 0 | yes | slower | yes | 88 |
| ehsanmok-json | 0.3.0 | 50.9 | 5.41 | 56.2 | 452 | 0 | yes | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `EmberJson`.
**Not both slower and larger than another named-JSON library:** `EmberJson`.

