# Experiment 1 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/01-json-library-bakeoff/kotlin/logs/kotlin/2026-10-11-145742.csv`
**Language:** kotlin
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 22.6 | 22.2 | 44.7 | 440 | 230 | yes | fastest | yes | 83 |
| moshi-codegen | 1.15.2 | 23.2 | 24.4 | 47.7 | 440 | 230 | yes | similar | yes | 81 |
| kotlinx-json | 1.8.1 | 33.1 | 57.5 | 95.1 | 440 | 230 | yes | slower | yes | 84 |
| gson | 2.14.0 | 41.3 | 55.7 | 98.6 | 440 | 230 | yes | slower | yes | 86 |
| jackson | 2.19.0 | 52.7 | 84.8 | 140 | 440 | 230 | yes | slower | yes | 84 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 15.6 | 22.3 | 37.6 | real |
| moshi-reflect | 15.9 | 22.4 | 38.5 | real |
| kotlinx-json | 23.5 | 39.1 | 63.1 | real |
| jackson | 31.7 | 54.1 | 86.7 | real |
| gson | 52.8 | 52.3 | 107 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `moshi-reflect`, `moshi-codegen`.
**Not both slower and larger than another named-JSON library:** `moshi-reflect`.

