# Experiment 11 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/11-memory-vs-stream/kotlin/logs/kotlin/2026-10-11-150809.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 25.2 | 24.8 | 50.2 | 440 | 230 | JSON | fastest | yes | 81 |
| protobuf | 4.35.0 | 36.3 | 30.6 | 68.7 | 155 | 174 | Protocol Buffers | slower | yes | 91 |
| jackson | 2.19.0 | 60.5 | 91.1 | 156 | 440 | 230 | JSON — common default | slower | yes | 84 |
| msgpack | 0.9.8 | 81.1 | 97.7 | 181 | 317 | 227 | MessagePack | slower | yes | 85 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 1 | 15.2 | 20.1 | 36.8 | real |
| protobuf | 1 | 24.9 | 26.2 | 51.4 | real |
| jackson | 1 | 33.4 | 56.6 | 92.9 | real |
| msgpack | 1 | 39.0 | 55.7 | 94.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `protobuf`.

