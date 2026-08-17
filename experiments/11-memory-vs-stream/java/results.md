# Experiment 11 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/11-memory-vs-stream/java/logs/java/2026-08-17-110923.csv`
**Language:** java
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 21.8 | 24.0 | 45.0 | 440 | — | JSON | fastest | yes | 92 |
| protobuf | 4.28.3 | 20.0 | 40.9 | 61.2 | 155 | — | Protocol Buffers | slower | yes | 91 |
| jackson | 2.18.3 | 46.5 | 55.0 | 105 | 440 | — | JSON — common default | slower | yes | 87 |
| msgpack | 0.9.8 | 70.1 | 55.8 | 128 | 317 | — | MessagePack | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| jsoniter | 1 | 14.4 | 16.8 | 32.0 | copied |
| jackson | 1 | 21.1 | 28.3 | 50.7 | real |
| protobuf | 1 | 18.2 | 36.2 | 54.3 | real |
| msgpack | 1 | 30.3 | 28.3 | 60.2 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`, `protobuf`.

