# Experiment 1 results — java

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/java/logs/java/2026-08-16-150521.csv`
**Language:** java
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 21.2 | 20.3 | 42.7 | 440 | — | yes | fastest | yes | 92 |
| fastjson2 | 2.0.57 | 33.1 | 35.1 | 69.0 | 440 | — | yes | slower | yes | 90 |
| gson | 2.12.1 | 35.0 | 33.6 | 70.9 | 440 | — | yes | slower | yes | 90 |
| moshi | 1.15.2 | 39.6 | 38.5 | 84.2 | 440 | — | yes | slower | yes | 91 |
| jackson | 2.18.3 | 41.4 | 49.9 | 92.8 | 440 | — | yes | slower | yes | 87 |
| dsl-json | 2.0.2 | 39.9 | 51.7 | 92.9 | 440 | — | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| jsoniter | 13.7 | 14.2 | 28.5 | copied |
| moshi | 20.0 | 26.2 | 45.7 | real |
| fastjson2 | 24.1 | 23.8 | 47.6 | copied |
| jackson | 20.0 | 27.3 | 48.2 | real |
| dsl-json | 23.7 | 28.5 | 53.7 | real |
| gson | 43.0 | 28.5 | 72.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `jsoniter`.
**Not both slower and larger than another named-JSON library:** `jsoniter`.

