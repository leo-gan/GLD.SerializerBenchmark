# Experiment 4 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/04-sensor-list-size/kotlin/logs/kotlin/2026-10-11-150029.csv`
**Language:** kotlin
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 19.2 | 21.2 | 43.9 | 220 | 862 | JSON — fast writer from Experiment 1 | fastest | yes | 91 |
| protobuf | 4.35.0 | 35.8 | 19.3 | 56.2 | 94 | 697 | Protocol Buffers | close | yes | 93 |
| kotlinx-cbor | 1.8.1 | 34.8 | 34.5 | 67.8 | 127 | 771 | CBOR | slower | yes | 92 |
| kotlinx-json | 1.8.1 | 33.5 | 58.3 | 93.1 | 220 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 91 |
| jackson-cbor | 2.19.0 | 48.0 | 72.1 | 123 | 125 | 771 | CBOR — Jackson | slower | yes | 94 |
| msgpack | 0.9.8 | 54.7 | 73.9 | 131 | 124 | 770 | MessagePack | slower | yes | 92 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 16.7 | 13.0 | 30.0 | 291 | 697 | Protocol Buffers | fastest | yes | 92 |
| moshi-codegen | 1.15.2 | 16.6 | 25.8 | 42.1 | 663 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| kotlinx-cbor | 1.8.1 | 26.2 | 19.9 | 46.8 | 347 | 771 | CBOR | slower | yes | 87 |
| jackson-cbor | 2.19.0 | 32.3 | 41.5 | 73.6 | 346 | 771 | CBOR — Jackson | slower | yes | 91 |
| kotlinx-json | 1.8.1 | 30.6 | 53.5 | 84.1 | 663 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 92 |
| msgpack | 0.9.8 | 40.8 | 46.8 | 89.6 | 346 | 770 | MessagePack | slower | yes | 92 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 10.5 | 10.4 | 25.4 | 1061 | 697 | Protocol Buffers | fastest | yes | 92 |
| kotlinx-cbor | 1.8.1 | 18.9 | 15.6 | 34.9 | 1213 | 771 | CBOR | slower | yes | 91 |
| jackson-cbor | 2.19.0 | 23.1 | 31.3 | 54.5 | 1212 | 771 | CBOR — Jackson | slower | yes | 91 |
| moshi-codegen | 1.15.2 | 17.5 | 37.7 | 55.5 | 2407 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 87 |
| msgpack | 0.9.8 | 24.8 | 30.6 | 58.4 | 1212 | 770 | MessagePack | slower | yes | 93 |
| kotlinx-json | 1.8.1 | 29.9 | 50.7 | 81.4 | 2407 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 94 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 9.85 | 11.3 | 21.0 | 4128 | 697 | Protocol Buffers | fastest | yes | 93 |
| kotlinx-cbor | 1.8.1 | 26.5 | 23.6 | 51.5 | 4664 | 771 | CBOR | slower | yes | 92 |
| jackson-cbor | 2.19.0 | 21.4 | 32.2 | 53.8 | 4664 | 771 | CBOR — Jackson | slower | yes | 87 |
| msgpack | 0.9.8 | 27.0 | 36.0 | 62.8 | 4663 | 770 | MessagePack | slower | yes | 94 |
| moshi-codegen | 1.15.2 | 47.7 | 118 | 168 | 9363 | 862 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| kotlinx-json | 1.8.1 | 61.5 | 110 | 172 | 9363 | 862 | JSON — compiler-generated kotlinx.serialization | slower | yes | 92 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| protobuf | 8 | 19.1 | 15.3 | 34.7 | real |
| moshi-codegen | 8 | 13.6 | 20.1 | 34.9 | real |
| kotlinx-cbor | 8 | 23.4 | 20.2 | 45.1 | copied |
| kotlinx-json | 8 | 21.8 | 43.2 | 64.4 | real |
| jackson-cbor | 8 | 27.8 | 43.3 | 70.5 | real |
| msgpack | 8 | 35.2 | 53.7 | 88.7 | real |
| protobuf | 32 | 13.8 | 12.9 | 26.8 | real |
| moshi-codegen | 32 | 10.5 | 18.4 | 28.8 | real |
| kotlinx-cbor | 32 | 18.5 | 15.4 | 34.7 | copied |
| kotlinx-json | 32 | 22.5 | 36.5 | 59.0 | real |
| jackson-cbor | 32 | 24.1 | 35.9 | 60.6 | real |
| msgpack | 32 | 26.3 | 35.0 | 62.0 | real |
| protobuf | 128 | 6.77 | 6.41 | 13.1 | real |
| kotlinx-cbor | 128 | 13.0 | 12.8 | 25.8 | copied |
| jackson-cbor | 128 | 12.3 | 22.8 | 35.3 | real |
| msgpack | 128 | 14.6 | 23.4 | 37.9 | real |
| moshi-codegen | 128 | 17.0 | 36.5 | 54.0 | real |
| kotlinx-json | 128 | 25.4 | 40.9 | 66.4 | real |
| protobuf | 512 | 12.9 | 14.8 | 28.0 | real |
| kotlinx-cbor | 512 | 25.3 | 21.0 | 46.1 | copied |
| jackson-cbor | 512 | 17.4 | 30.1 | 49.0 | real |
| msgpack | 512 | 21.9 | 35.1 | 57.4 | real |
| kotlinx-json | 512 | 57.3 | 99.8 | 158 | real |
| moshi-codegen | 512 | 48.9 | 120 | 168 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `moshi-codegen`. Small gap: `protobuf`. Time/size front: `moshi-codegen`, `protobuf`.

**32 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**128 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**512 numbers, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

