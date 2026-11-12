# Experiment 11 results — java

**Date:** 2026-11-12
**Raw file:** `experiments/03-memory-vs-stream/java/logs/java/2026-11-12-163840.csv`
**Language:** java
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 25.6 | 26.3 | 53.5 | 440 | 230 | JSON | fastest | yes | 95 |
| protobuf | 4.36.2 | 58.0 | 43.0 | 101 | 155 | 174 | Protocol Buffers | slower | yes | 92 |
| jackson | 2.22.4 | 47.0 | 57.4 | 108 | 440 | 230 | JSON — common default | slower | yes | 87 |
| msgpack | 0.9.12 | 75.5 | 53.4 | 131 | 317 | 227 | MessagePack | slower | yes | 82 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| jsoniter | 1 | 16.9 | 18.2 | 35.6 | copied |
| jackson | 1 | 25.0 | 34.6 | 61.5 | real |
| msgpack | 1 | 33.7 | 28.7 | 63.1 | real |
| protobuf | 1 | 40.1 | 39.6 | 86.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `protobuf`.

