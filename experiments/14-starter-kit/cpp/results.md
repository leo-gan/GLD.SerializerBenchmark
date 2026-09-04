# Experiment 14 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/14-starter-kit/cpp/logs/cpp/2026-09-04-111946.csv`
**Language:** cpp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 4.21 | 1.77 | 6.08 | 164 | 182 | yes | fastest | yes | 92 |
| msgpack | msgpack-cxx | 2.87 | 4.65 | 7.62 | 332 | 228 | yes | slower | yes | 96 |
| simdjson | 3.10.1 | 5.21 | 13.0 | 17.9 | 458 | 238 | yes | slower | yes | 95 |
| nlohmann_json | 3.11.3 | 5.25 | 16.9 | 21.8 | 458 | 238 | yes | slower | yes | 92 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 4.09 | 1.78 | 6.08 | copied |
| msgpack | 2.66 | 5.14 | 8.00 | real |
| simdjson | 5.74 | 12.6 | 18.2 | copied |
| nlohmann_json | 6.63 | 17.6 | 24.2 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `protobuf-wire`.
**Not both slower and larger than another library in the kit:** `protobuf-wire`.

