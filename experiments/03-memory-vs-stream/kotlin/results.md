# Experiment 11 results — kotlin

**Date:** 2026-11-12
**Raw file:** `experiments/03-memory-vs-stream/kotlin/logs/kotlin/2026-11-12-163857.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 28.3 | 29.1 | 60.4 | 440 | 230 | JSON | fastest | yes | 84 |
| protobuf | 4.36.2 | 37.8 | 31.3 | 68.9 | 155 | 174 | Protocol Buffers | close | yes | 93 |
| jackson | 2.22.4 | 73.1 | 108 | 194 | 440 | 230 | JSON — common default | slower | yes | 91 |
| msgpack | 0.9.12 | 93.6 | 101 | 199 | 317 | 227 | MessagePack | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 1 | 18.9 | 24.6 | 45.1 | real |
| protobuf | 1 | 31.3 | 31.8 | 64.1 | real |
| jackson | 1 | 47.4 | 65.9 | 111 | real |
| msgpack | 1 | 48.6 | 63.7 | 114 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`. Time/size front: `moshi-codegen`, `protobuf`.

