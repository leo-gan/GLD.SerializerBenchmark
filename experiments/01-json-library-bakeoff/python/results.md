# Experiment 1 results — python

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/python/logs/python/2026-08-16-143516.csv`
**Language:** python
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.52 | 2.36 | 3.89 | 448 | 229 | yes | fastest | yes | 92 |
| msgspec | 0.21.1 | 1.91 | 2.46 | 4.35 | 192 | 165 | no (list) | — | yes | 90 |
| serpyco-rs | 1.21.0 | 3.33 | 4.54 | 7.86 | 448 | 229 | yes | slower | yes | 93 |
| mashumaro | 3.22 | 3.75 | 8.02 | 11.8 | 448 | 229 | yes | slower | yes | 90 |
| rapidjson | 1.23 | 6.01 | 7.06 | 13.2 | 448 | 229 | yes | slower | yes | 89 |
| json | python-3.14.0 | 12.9 | 8.53 | 21.6 | 448 | 229 | yes | slower | yes | 92 |
| pydantic | 2.13.4 | 9.49 | 16.9 | 26.2 | 448 | 229 | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| orjson | 1.92 | 2.64 | 4.63 | copied |
| msgspec | 2.63 | 3.22 | 5.89 | real |
| serpyco-rs | 3.73 | 4.92 | 8.63 | copied |
| mashumaro | 4.10 | 8.46 | 12.7 | copied |
| rapidjson | 6.34 | 7.53 | 13.9 | copied |
| json | 13.1 | 8.98 | 22.1 | copied |
| pydantic | 9.62 | 17.4 | 26.8 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `orjson`.
**Not both slower and larger than another named-JSON library:** `orjson`.

