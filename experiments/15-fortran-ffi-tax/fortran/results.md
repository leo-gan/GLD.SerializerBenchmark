# Experiment 15 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/15-fortran-ffi-tax/fortran/logs/fortran/ffi-2026-10-11-151406.csv`
**Language:** fortran
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| flatcc | 0.6.3 | 0.69 | 0.22 | 0.91 | 240 | — | yes | fastest | yes | 94 |
| nanopb | 0.4.9.2 | 0.70 | 0.38 | 1.06 | 169 | — | yes | slower | yes | 91 |
| avro-c | 1.11.3 | 0.64 | 0.51 | 1.15 | 214 | — | yes | slower | yes | 92 |
| mpack | 1.1.1 | 0.81 | 1.41 | 2.20 | 337 | — | yes | slower | yes | 93 |
| yyjson | 0.10.0 | 3.20 | 1.69 | 4.89 | 464 | — | yes | slower | yes | 92 |
| tinycbor | 0.6.0 | 1.17 | 5.69 | 6.87 | 344 | — | yes | slower | yes | 97 |
| libbson | 1.27.5 | 4.38 | 2.94 | 7.30 | 581 | — | yes | slower | yes | 93 |
| cJSON | 1.7.19 | 6.35 | 4.09 | 10.5 | 464 | — | yes | slower | yes | 90 |
| ion-c | 1.1.6 | 6.34 | 8.17 | 14.5 | 251 | — | yes | slower | yes | 90 |
| libyaml | 0.2.5 | 8.86 | 13.4 | 22.2 | 465 | — | yes | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `flatcc`.
**Not both slower and larger than another named-JSON library:** `flatcc`, `nanopb`.

