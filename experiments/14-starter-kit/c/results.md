# Experiment 14 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/c/logs/c/2026-09-29-185657.csv`
**Language:** c
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 0.66 | 0.42 | 1.08 | 166 | 183 | yes | fastest | yes | 90 |
| mpack | 1.1.1 | 0.87 | 1.90 | 2.76 | 335 | 236 | yes | slower | yes | 91 |
| yyjson | 0.10.0 | 3.27 | 2.14 | 5.40 | 460 | 239 | yes | slower | yes | 83 |
| cJSON | 1.7.19 | 6.90 | 6.11 | 13.0 | 460 | 239 | yes | slower | yes | 87 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf-c | 1.02 | 0.69 | 1.73 | copied |
| mpack | 1.25 | 2.32 | 3.59 | copied |
| yyjson | 4.50 | 2.87 | 7.32 | real |
| cJSON | 8.21 | 8.02 | 16.2 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `protobuf-c`.
**Not both slower and larger than another library in the kit:** `protobuf-c`.

