# Experiment 3 results — python

**Date:** 2026-08-16
**Raw file:** `experiments/03-one-language-store/python/logs/python/2026-08-16-160015.csv`
**Language:** python
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 0.67 | 1.02 | 1.70 | 168 | 138 | other languages can read — JSON | fastest | yes | 96 |
| msgspec-msgpack | 0.21.1 | 0.93 | 0.92 | 1.86 | 52 | 72 | other languages can read — MessagePack | close | yes | 95 |
| protobuf | 7.35.1 | 1.53 | 1.59 | 3.12 | 50 | 71 | other languages can read — Protocol Buffers | slower | yes | 87 |
| pickle | python-3.14.0 | 4.15 | 2.93 | 7.15 | 202 | 194 | one language — pickle | slower | yes | 98 |
| cloudpickle | 3.1.2 | 12.6 | 3.10 | 15.5 | 202 | 194 | one language — cloudpickle | slower | yes | 96 |
| dill | 0.4.1 | 49.3 | 7.39 | 57.2 | 202 | 194 | one language — dill | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| orjson | 1 | 0.94 | 1.25 | 2.23 | copied |
| msgspec-msgpack | 1 | 1.28 | 1.50 | 2.81 | real |
| protobuf | 1 | 1.81 | 1.82 | 3.65 | copied |
| pickle | 1 | 4.72 | 3.68 | 8.50 | real |
| cloudpickle | 1 | 11.7 | 3.60 | 15.3 | real |
| dill | 1 | 50.0 | 7.41 | 57.5 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `orjson`. Small gap: `msgspec-msgpack`. Time/size front: `orjson`, `msgspec-msgpack`, `protobuf`.

