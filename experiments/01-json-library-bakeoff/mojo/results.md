# Experiment 1 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/01-json-library-bakeoff/mojo/logs/mojo/2026-09-12-132603.csv`
**Language:** mojo
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.57 | 1.15 | 1.73 | 452 | 0 | yes | fastest | yes | 78 |
| EmberJson | 0.3.4 | 0.52 | 1.65 | 2.17 | 452 | 0 | yes | slower | yes | 84 |
| ehsanmok-json | 0.3.1 | 0.74 | 6.61 | 7.37 | 452 | 0 | yes | slower | yes | 76 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `mojo-json`.
**Not both slower and larger than another named-JSON library:** `mojo-json`.

