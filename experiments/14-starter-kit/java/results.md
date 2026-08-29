# Experiment 14 results — java

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/java/logs/java/2026-08-28-182218.csv`
**Language:** java
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 25.1 | 26.3 | 52.8 | 440 | 230 | yes | fastest | yes | 90 |
| jackson | 2.18.3 | 43.8 | 49.8 | 94.1 | 440 | 230 | yes | slower | yes | 87 |
| protobuf | 4.28.3 | 59.1 | 42.4 | 101 | 155 | 174 | yes | slower | yes | 93 |
| msgpack | 0.9.8 | 63.1 | 52.2 | 118 | 317 | 227 | yes | slower | yes | 85 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| jsoniter | 16.4 | 17.8 | 34.8 | copied |
| jackson | 23.2 | 28.7 | 54.1 | real |
| msgpack | 31.4 | 28.7 | 61.2 | real |
| protobuf | 39.9 | 34.1 | 77.1 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `jsoniter`.
**Not both slower and larger than another library in the kit:** `jsoniter`, `protobuf`.

