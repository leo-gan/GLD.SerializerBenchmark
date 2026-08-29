# Experiment 14 results — c

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/c/logs/c/2026-08-28-182249.csv`
**Language:** c
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| protobuf-c | 1.5.0 | 0.71 | 0.42 | 1.12 | 166 | 183 | yes | fastest | yes | 90 |
| mpack | 1.1 | 0.86 | 1.89 | 2.73 | 335 | 236 | yes | slower | yes | 88 |
| yyjson | 0.10.0 | 3.36 | 2.20 | 5.58 | 460 | 239 | yes | slower | yes | 90 |
| cJSON | 1.7.18 | 7.29 | 6.21 | 13.5 | 460 | 239 | yes | slower | yes | 87 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf-c | 0.96 | 0.64 | 1.61 | copied |
| mpack | 1.12 | 2.23 | 3.34 | copied |
| yyjson | 4.40 | 2.87 | 7.30 | real |
| cJSON | 8.26 | 7.44 | 15.7 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `protobuf-c`.
**Not both slower and larger than another library in the kit:** `protobuf-c`.

