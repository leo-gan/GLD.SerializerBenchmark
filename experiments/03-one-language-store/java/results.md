# Experiment 3 results — java

**Date:** 2026-08-16
**Raw file:** `experiments/03-one-language-store/java/logs/java/2026-08-16-160016.csv`
**Language:** java
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 12.4 | 12.8 | 25.6 | 50 | — | other languages can read — Protocol Buffers | fastest | yes | 95 |
| jsoniter | 0.9.23 | 16.2 | 14.9 | 31.4 | 150 | — | other languages can read — JSON | slower | yes | 93 |
| fory | 1.3.0 | 18.5 | 16.0 | 35.1 | 133 | — | one language — Apache Fory (Java path) | slower | yes | 94 |
| kryo | 5.6.2 | 25.1 | 17.4 | 42.1 | 46 | — | one language — Kryo | slower | yes | 94 |
| hessian | 4.0.66 | 21.1 | 20.2 | 42.5 | 143 | — | one language — Hessian2 | slower | yes | 90 |
| java-serialization | 21.0.11 | 43.7 | 75.0 | 119 | 206 | — | one language — JDK ObjectOutputStream | slower | yes | 96 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| jsoniter | 1 | 11.6 | 11.2 | 23.1 | copied |
| protobuf | 1 | 11.8 | 13.1 | 26.1 | real |
| fory | 1 | 14.5 | 13.8 | 28.6 | copied |
| kryo | 1 | 17.4 | 11.9 | 29.6 | real |
| hessian | 1 | 16.3 | 16.7 | 32.9 | real |
| java-serialization | 1 | 28.1 | 60.4 | 90.4 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `kryo`.

