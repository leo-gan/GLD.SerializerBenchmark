# Experiment 15 results — c

**Date:** 2026-10-10
**Raw file:** `experiments/15-fortran-ffi-tax/c/logs/c/ffi.csv`
**Language:** c
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| flatcc | 0.6.3 | 0.87 | 0.20 | 1.07 | 236 | 201 | yes | fastest | yes | 889 |
| nanopb | 0.4.9.2 | 0.75 | 0.44 | 1.19 | 166 | 183 | yes | slower | yes | 894 |
| avro-c | 1.11.3 | 0.85 | 0.74 | 1.59 | 210 | 185 | yes | slower | yes | 872 |
| mpack | 1.1.1 | 0.96 | 2.13 | 3.11 | 335 | 236 | yes | slower | yes | 926 |
| yyjson | 0.10.0 | 3.58 | 2.28 | 5.86 | 460 | 239 | yes | slower | yes | 888 |
| tinycbor | 0.6.0 | 1.25 | 6.46 | 7.72 | 343 | 226 | yes | slower | yes | 899 |
| libbson | 1.27.5 | 4.58 | 3.47 | 8.06 | 577 | 296 | yes | slower | yes | 895 |
| cJSON | 1.7.19 | 7.52 | 6.35 | 13.9 | 460 | 239 | yes | slower | yes | 909 |
| ion-c | 1.1.6 | 8.67 | 12.5 | 21.2 | 249 | 264 | yes | slower | yes | 916 |
| libyaml | 0.2.5 | 11.0 | 22.6 | 33.6 | 461 | 232 | yes | slower | yes | 890 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| yyjson | 2.38 | 1.33 | 3.72 | real |
| ion-c | 6.12 | 8.41 | 14.5 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `flatcc`.
**Not both slower and larger than another named-JSON library:** `flatcc`, `nanopb`.

