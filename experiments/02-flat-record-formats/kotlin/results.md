# Experiment 2 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/02-flat-record-formats/kotlin/logs/kotlin/2026-08-27-181711.csv`
**Language:** kotlin
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 24.9 | 12.5 | 37.8 | 50 | 2114 | Protocol Buffers | fastest | yes | 88 |
| moshi-codegen | 1.15.2 | 23.2 | 26.7 | 50.0 | 158 | 2452 | JSON — fast writer from Experiment 1 | slower | yes | 87 |
| kotlinx-json | 1.8.1 | 35.7 | 67.5 | 102 | 158 | 2452 | JSON — compiler-generated kotlinx.serialization | slower | yes | 92 |
| msgpack | 0.9.8 | 63.0 | 85.0 | 151 | 114 | 2254 | MessagePack | slower | yes | 87 |
| jackson | 2.18.3 | 59.5 | 95.5 | 158 | 158 | 2452 | JSON — common default | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 66.2 | 49.9 | 110 | 4841 | 2114 | Protocol Buffers | fastest | yes | 93 |
| moshi-codegen | 1.15.2 | 93.7 | 126 | 222 | 15546 | 2452 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| kotlinx-json | 1.8.1 | 103 | 144 | 246 | 15546 | 2452 | JSON — compiler-generated kotlinx.serialization | slower | yes | 86 |
| jackson | 2.18.3 | 121 | 234 | 356 | 15546 | 2452 | JSON — common default | slower | yes | 91 |
| msgpack | 0.9.8 | 151 | 214 | 368 | 11031 | 2254 | MessagePack | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 15.2 | 12.1 | 28.1 | real |
| moshi-codegen | 1 | 13.2 | 17.3 | 30.7 | real |
| kotlinx-json | 1 | 23.6 | 38.4 | 62.1 | real |
| jackson | 1 | 29.6 | 49.7 | 80.1 | real |
| msgpack | 1 | 35.2 | 47.8 | 83.4 | real |
| protobuf | 100 | 31.5 | 35.5 | 68.0 | real |
| moshi-codegen | 100 | 70.0 | 107 | 177 | real |
| kotlinx-json | 100 | 83.0 | 103 | 189 | real |
| jackson | 100 | 70.2 | 155 | 226 | real |
| msgpack | 100 | 88.1 | 141 | 228 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

