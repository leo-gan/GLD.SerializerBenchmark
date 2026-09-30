# Experiment 1 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/c/logs/c/2026-09-29-184036.csv`
**Language:** c
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.52 | 2.18 | 5.66 | 460 | 239 | yes | fastest | yes | 90 |
| cJSON | 1.7.19 | 7.31 | 6.51 | 13.9 | 460 | 239 | yes | slower | yes | 90 |
| json-c | 0.15 | 8.84 | 9.96 | 18.8 | 460 | 239 | yes | slower | yes | 91 |
| jansson | 2.15.1 | 11.6 | 10.5 | 22.1 | 460 | 239 | yes | slower | yes | 88 |
| parson | 1.5.3 | 18.0 | 8.08 | 26.2 | 460 | 239 | yes | slower | yes | 85 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| yyjson | 4.44 | 2.91 | 7.36 | real |
| cJSON | 8.14 | 8.04 | 16.2 | copied |
| json-c | 9.47 | 9.93 | 19.4 | copied |
| jansson | 12.5 | 11.8 | 24.4 | copied |
| parson | 19.3 | 10.3 | 29.6 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `yyjson`.
**Not both slower and larger than another named-JSON library:** `yyjson`.

