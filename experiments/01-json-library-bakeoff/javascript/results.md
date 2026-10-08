# Experiment 1 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/javascript/logs/javascript/2026-09-29-184048.csv`
**Language:** javascript
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.11 | 5.06 | 9.27 | 448 | 230 | yes | fastest | yes | 89 |
| fast-json-stringify | 6.4.0 | 7.74 | 4.85 | 13.0 | 448 | 230 | yes | slower | yes | 86 |
| simdjson-parse+JSON.stringify | 0.9.2 | 4.00 | 23.1 | 28.2 | 448 | 230 | yes | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `JSON.stringify`.
**Not both slower and larger than another named-JSON library:** `JSON.stringify`.

