# Experiment 1 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/01-json-library-bakeoff/kotlin/logs/kotlin/2026-08-27-181111.csv`
**Language:** kotlin
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 25.5 | 24.5 | 51.0 | 440 | 230 | yes | fastest | yes | 87 |
| moshi-reflect | 1.15.2 | 23.6 | 26.8 | 52.2 | 440 | 230 | yes | similar | yes | 92 |
| kotlinx-json | 1.8.1 | 37.3 | 69.0 | 105 | 440 | 230 | yes | slower | yes | 88 |
| gson | 2.12.1 | 49.8 | 60.0 | 110 | 440 | 230 | yes | slower | yes | 91 |
| jackson | 2.18.3 | 60.2 | 93.9 | 161 | 440 | 230 | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 15.4 | 19.7 | 35.5 | real |
| moshi-reflect | 15.5 | 20.4 | 36.4 | real |
| kotlinx-json | 27.0 | 42.3 | 71.7 | real |
| jackson | 33.1 | 56.6 | 91.2 | real |
| gson | 51.3 | 46.3 | 97.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `moshi-codegen`, `moshi-reflect`.
**Not both slower and larger than another named-JSON library:** `moshi-codegen`.

