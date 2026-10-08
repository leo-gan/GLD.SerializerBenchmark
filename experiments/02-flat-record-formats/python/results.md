# Experiment 2 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/python/logs/python/2026-09-29-184121.csv`
**Language:** python
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.06 | 1.26 | 2.37 | 52 | 1994 | MessagePack — msgspec | fastest | yes | 79 |
| orjson | 3.12.0 | 1.28 | 1.78 | 3.08 | 168 | 2469 | JSON — fast writer from Experiment 1 | slower | yes | 93 |
| protobuf | 7.36.1 | 2.48 | 2.36 | 4.85 | 50 | 2114 | Protocol Buffers | slower | yes | 77 |
| msgpack | 1.2.2 | 2.58 | 3.31 | 5.95 | 124 | 2280 | MessagePack | slower | yes | 88 |
| json | python-3.14.0 | 9.71 | 7.76 | 17.5 | 168 | 2469 | JSON — ships with Python | slower | yes | 93 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 11.4 | 19.4 | 30.8 | 4831 | 1994 | MessagePack — msgspec | fastest | yes | 84 |
| protobuf | 7.36.1 | 17.8 | 16.1 | 33.8 | 4841 | 2114 | Protocol Buffers | slower | yes | 79 |
| orjson | 3.12.0 | 20.2 | 42.1 | 62.2 | 16546 | 2469 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| msgpack | 1.2.2 | 47.3 | 64.3 | 112 | 12031 | 2280 | MessagePack | slower | yes | 79 |
| json | python-3.14.0 | 129 | 114 | 244 | 16546 | 2469 | JSON — ships with Python | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| msgspec-msgpack | 1 | 1.67 | 1.92 | 3.57 | copied |
| orjson | 1 | 1.47 | 2.11 | 3.61 | copied |
| protobuf | 1 | 2.64 | 2.58 | 5.24 | copied |
| msgpack | 1 | 2.58 | 3.88 | 6.46 | copied |
| json | 1 | 9.57 | 7.68 | 17.3 | copied |
| msgspec-msgpack | 100 | 13.0 | 21.7 | 35.1 | copied |
| protobuf | 100 | 20.5 | 17.3 | 37.6 | copied |
| orjson | 100 | 21.6 | 41.3 | 63.5 | copied |
| msgpack | 100 | 50.0 | 65.5 | 116 | copied |
| json | 100 | 132 | 112 | 245 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`.

