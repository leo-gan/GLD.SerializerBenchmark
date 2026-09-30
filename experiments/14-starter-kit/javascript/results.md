# Experiment 14 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/javascript/logs/javascript/2026-09-29-185710.csv`
**Language:** javascript
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.21 | 5.34 | 9.27 | 448 | 230 | yes | fastest | yes | 93 |
| msgpackr | 1.12.1 | 4.99 | 10.0 | 15.1 | 345 | 232 | yes | slower | yes | 86 |
| google-protobuf | 3.21.4 | 18.3 | 13.6 | 34.0 | 155 | 174 | yes | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `JSON.stringify`.
**Not both slower and larger than another library in the kit:** `JSON.stringify`, `msgpackr`, `google-protobuf`.

