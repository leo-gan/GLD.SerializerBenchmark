# Experiment 2 results — python

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/python/logs/python/2026-08-16-154151.csv`
**Language:** python
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 0.75 | 0.94 | 1.71 | 52 | 1994 | MessagePack — msgspec | fastest | yes | 91 |
| orjson | 3.11.9 | 0.71 | 1.02 | 1.79 | 168 | 2469 | JSON — fast writer from Experiment 1 | close | yes | 96 |
| protobuf | 7.35.1 | 1.76 | 1.52 | 3.29 | 50 | 2114 | Protocol Buffers | slower | yes | 92 |
| msgpack | 1.2.1 | 1.73 | 2.39 | 4.13 | 124 | 2280 | MessagePack | slower | yes | 90 |
| json | python-3.14.0 | 7.14 | 4.51 | 11.7 | 168 | 2469 | JSON — ships with Python | slower | yes | 95 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 9.72 | 17.1 | 26.8 | 4831 | 1994 | MessagePack — msgspec | fastest | yes | 85 |
| protobuf | 7.35.1 | 15.9 | 14.5 | 30.7 | 4841 | 2114 | Protocol Buffers | slower | yes | 75 |
| orjson | 3.11.9 | 16.7 | 35.7 | 52.2 | 16546 | 2469 | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| msgpack | 1.2.1 | 44.3 | 59.1 | 103 | 12031 | 2280 | MessagePack | slower | yes | 84 |
| json | python-3.14.0 | 111 | 101 | 213 | 16546 | 2469 | JSON — ships with Python | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| orjson | 1 | 0.90 | 1.17 | 2.06 | copied |
| msgspec-msgpack | 1 | 1.21 | 1.50 | 2.71 | real |
| protobuf | 1 | 1.93 | 1.69 | 3.65 | copied |
| msgpack | 1 | 1.87 | 3.18 | 5.07 | real |
| json | 1 | 7.21 | 4.78 | 12.0 | copied |
| msgspec-msgpack | 100 | 10.1 | 18.5 | 28.7 | real |
| protobuf | 100 | 17.4 | 15.1 | 32.6 | copied |
| orjson | 100 | 18.4 | 37.4 | 56.0 | copied |
| msgpack | 100 | 45.7 | 61.4 | 107 | real |
| json | 100 | 111 | 102 | 213 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: `orjson`. Time/size front: `msgspec-msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`.

