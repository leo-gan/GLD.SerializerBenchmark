# Experiment 3 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/03-one-language-store/python/logs/python/2026-09-29-184148.csv`
**Language:** python
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec-msgpack | 0.21.1 | 1.07 | 1.15 | 2.24 | 52 | 72 | other languages can read — MessagePack | fastest | yes | 78 |
| orjson | 3.12.0 | 1.23 | 1.91 | 3.18 | 168 | 138 | other languages can read — JSON | slower | yes | 95 |
| protobuf | 7.36.1 | 2.75 | 2.20 | 4.99 | 50 | 71 | other languages can read — Protocol Buffers | slower | yes | 77 |
| pickle | python-3.14.0 | 6.44 | 4.23 | 10.7 | 202 | 194 | one language — pickle | slower | yes | 91 |
| cloudpickle | 3.1.2 | 17.5 | 4.47 | 22.2 | 202 | 194 | one language — cloudpickle | slower | yes | 85 |
| dill | 0.4.1 | 68.3 | 10.2 | 79.0 | 202 | 194 | one language — dill | slower | yes | 82 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| orjson | 1 | 1.43 | 2.15 | 3.60 | copied |
| msgspec-msgpack | 1 | 1.75 | 2.06 | 3.82 | copied |
| protobuf | 1 | 2.80 | 2.34 | 5.19 | copied |
| pickle | 1 | 6.58 | 5.17 | 11.7 | real |
| cloudpickle | 1 | 16.0 | 5.19 | 21.5 | real |
| dill | 1 | 66.6 | 9.61 | 76.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `msgspec-msgpack`. Small gap: —. Time/size front: `msgspec-msgpack`, `protobuf`.

