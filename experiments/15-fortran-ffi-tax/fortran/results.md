# Experiment 15 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/15-fortran-ffi-tax/fortran/logs/fortran/ffi-2026-10-10-134333.csv`
**Language:** fortran
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| flatcc | 0.6.3 | 0.71 | 0.24 | 0.96 | 240 | — | yes | fastest | yes | 82 |
| nanopb | 0.4.9.2 | 0.74 | 0.39 | 1.13 | 169 | — | yes | slower | yes | 85 |
| avro-c | 1.11.3 | 0.71 | 0.60 | 1.30 | 214 | — | yes | slower | yes | 84 |
| mpack | 1.1.1 | 0.80 | 1.55 | 2.38 | 337 | — | yes | slower | yes | 88 |
| yyjson | 0.10.0 | 3.48 | 1.87 | 5.34 | 464 | — | yes | slower | yes | 86 |
| tinycbor | 0.6.0 | 1.25 | 6.13 | 7.41 | 344 | — | yes | slower | yes | 84 |
| libbson | 1.27.5 | 4.86 | 3.13 | 8.03 | 581 | — | yes | slower | yes | 86 |
| cJSON | 1.7.19 | 7.30 | 4.65 | 12.0 | 464 | — | yes | slower | yes | 83 |
| ion-c | 1.1.6 | 6.87 | 9.75 | 16.7 | 251 | — | yes | slower | yes | 83 |
| libyaml | 0.2.5 | 9.32 | 18.4 | 27.7 | 465 | — | yes | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `flatcc`.
**Not both slower and larger than another named-JSON library:** `flatcc`, `nanopb`.

