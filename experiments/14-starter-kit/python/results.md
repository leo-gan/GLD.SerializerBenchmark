# Experiment 14 results — python

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/python/logs/python/2026-08-28-182214.csv`
**Language:** python
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 2.06 | 2.31 | 4.37 | 129 | 149 | yes | fastest | yes | 93 |
| orjson | 3.11.9 | 2.23 | 2.87 | 5.18 | 448 | 229 | yes | similar | yes | 83 |
| protobuf | 7.35.1 | 3.41 | 3.28 | 6.69 | 155 | 174 | yes | slower | yes | 94 |
| json | python-3.14.0 | 15.1 | 11.1 | 26.2 | 448 | 229 | yes | slower | yes | 96 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| msgspec-msgpack | 2.88 | 3.17 | 6.03 | copied |
| orjson | 2.81 | 3.47 | 6.10 | copied |
| protobuf | 5.05 | 4.39 | 9.33 | copied |
| json | 16.4 | 12.5 | 28.7 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `msgspec-msgpack`, `orjson`.
**Not both slower and larger than another library in the kit:** `msgspec-msgpack`.

