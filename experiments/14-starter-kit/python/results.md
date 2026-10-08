# Experiment 14 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/python/logs/python/2026-09-29-185707.csv`
**Language:** python
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 2.17 | 2.57 | 4.74 | 129 | 149 | yes | fastest | yes | 95 |
| orjson | 3.12.0 | 2.37 | 3.40 | 5.76 | 448 | 229 | yes | close | yes | 83 |
| protobuf | 7.36.1 | 4.67 | 4.03 | 8.54 | 155 | 174 | yes | slower | yes | 96 |
| json | python-3.14.0 | 16.3 | 12.4 | 28.8 | 448 | 229 | yes | slower | yes | 94 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| orjson | 2.80 | 3.68 | 6.49 | copied |
| msgspec-msgpack | 3.18 | 3.65 | 6.91 | copied |
| protobuf | 5.90 | 4.84 | 10.8 | copied |
| json | 18.3 | 13.0 | 31.3 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `msgspec-msgpack`.
**A small gap (a different record could change the order):** `orjson`.
**Not both slower and larger than another library in the kit:** `msgspec-msgpack`.

