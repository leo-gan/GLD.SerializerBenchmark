# Experiment 1 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/python/logs/python/2026-09-29-184046.csv`
**Language:** python
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.44 | 3.16 | 5.63 | 448 | 229 | yes | fastest | yes | 90 |
| msgspec | 0.21.1 | 2.76 | 3.22 | 6.10 | 192 | 165 | no (list) | — | yes | 95 |
| serpyco-rs | 1.22.0 | 5.17 | 6.08 | 11.2 | 448 | 229 | yes | slower | yes | 93 |
| mashumaro | 3.22 | 4.48 | 9.85 | 14.3 | 448 | 229 | yes | slower | yes | 94 |
| rapidjson | 1.25 | 8.41 | 8.47 | 17.0 | 448 | 229 | yes | slower | yes | 97 |
| json | python-3.14.0 | 15.6 | 11.6 | 27.3 | 448 | 229 | yes | slower | yes | 95 |
| pydantic | 2.13.5 | 14.7 | 17.6 | 32.2 | 448 | 229 | yes | slower | yes | 97 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| orjson | 2.85 | 3.32 | 6.23 | copied |
| msgspec | 3.95 | 4.38 | 8.26 | copied |
| serpyco-rs | 5.82 | 6.56 | 12.3 | copied |
| mashumaro | 5.11 | 10.7 | 15.8 | copied |
| rapidjson | 9.65 | 9.46 | 19.3 | copied |
| json | 17.6 | 12.3 | 29.8 | copied |
| pydantic | 16.0 | 18.2 | 34.6 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `orjson`.
**Not both slower and larger than another named-JSON library:** `orjson`.

