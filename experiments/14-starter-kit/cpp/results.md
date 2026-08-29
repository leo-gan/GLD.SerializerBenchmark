# Experiment 14 results — cpp

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/cpp/logs/cpp/2026-08-28-182253.csv`
**Language:** cpp
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 2.07 | 1.08 | 3.19 | 164 | 182 | yes | fastest | yes | 87 |
| msgpack | msgpack-cxx | 1.42 | 2.12 | 3.55 | 332 | 228 | yes | slower | yes | 84 |
| simdjson | 3.10.1 | 2.81 | 6.84 | 9.69 | 458 | 238 | yes | slower | yes | 91 |
| nlohmann_json | 3.11.3 | 2.81 | 9.64 | 12.4 | 458 | 238 | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 2.04 | 1.06 | 3.09 | copied |
| msgpack | 1.44 | 2.48 | 3.92 | real |
| simdjson | 3.03 | 6.70 | 9.76 | copied |
| nlohmann_json | 3.82 | 9.97 | 13.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `protobuf-wire`.
**Not both slower and larger than another library in the kit:** `protobuf-wire`.

