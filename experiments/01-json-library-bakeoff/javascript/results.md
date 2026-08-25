# Experiment 1 results — javascript

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/javascript/logs/javascript/2026-08-16-150529.csv`
**Language:** javascript
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.10 | 3.62 | 7.06 | 448 | — | yes | fastest | yes | 91 |
| fast-json-stringify | 6.4.0 | 6.49 | 4.07 | 10.8 | 448 | — | yes | slower | yes | 86 |
| simdjson-parse+JSON.stringify | 0.9.2 | 3.26 | 16.7 | 20.3 | 448 | — | yes | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `JSON.stringify`.
**Not both slower and larger than another named-JSON library:** `JSON.stringify`.

