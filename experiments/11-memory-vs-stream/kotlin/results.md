# Experiment 11 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/11-memory-vs-stream/kotlin/logs/kotlin/2026-08-27-181806.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 23.3 | 24.8 | 48.2 | 440 | 230 | JSON | fastest | yes | 83 |
| protobuf | 4.28.3 | 33.1 | 28.3 | 62.3 | 155 | 174 | Protocol Buffers | slower | yes | 88 |
| jackson | 2.18.3 | 54.8 | 86.9 | 144 | 440 | 230 | JSON — common default | slower | yes | 83 |
| msgpack | 0.9.8 | 72.4 | 95.4 | 170 | 317 | 227 | MessagePack | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 1 | 15.2 | 20.6 | 36.2 | real |
| protobuf | 1 | 20.4 | 23.3 | 43.7 | real |
| jackson | 1 | 32.8 | 58.3 | 92.1 | real |
| msgpack | 1 | 43.3 | 63.6 | 107 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`.

