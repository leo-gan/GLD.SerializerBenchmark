# Experiment 1 results — c

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/c/logs/c/2026-08-16-150531.csv`
**Language:** c
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.27 | 1.48 | 4.67 | 460 | — | yes | fastest | yes | 86 |
| cJSON | 1.7.18 | 5.56 | 3.92 | 9.50 | 460 | — | yes | slower | yes | 90 |
| json-c | 0.15 | 7.39 | 9.15 | 16.6 | 460 | — | yes | slower | yes | 90 |
| jansson | 2.14 | 9.07 | 8.64 | 17.8 | 460 | — | yes | slower | yes | 89 |
| parson | 1.5.3 | 14.6 | 5.77 | 20.3 | 460 | — | yes | slower | yes | 87 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| yyjson | 2.85 | 1.69 | 4.58 | copied |
| cJSON | 6.85 | 5.43 | 12.3 | copied |
| json-c | 8.29 | 8.65 | 17.0 | copied |
| jansson | 10.7 | 10.3 | 21.1 | copied |
| parson | 16.5 | 8.10 | 24.6 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `yyjson`.
**Not both slower and larger than another named-JSON library:** `yyjson`.

