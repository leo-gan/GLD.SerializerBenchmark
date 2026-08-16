# Experiment 2 results — java

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/java/logs/java/2026-08-16-154202.csv`
**Language:** java
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 11.9 | 11.7 | 23.4 | 50 | — | Protocol Buffers | fastest | yes | 95 |
| jsoniter | 0.9.23 | 15.6 | 14.5 | 30.5 | 150 | — | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| msgpack | 0.9.8 | 37.4 | 32.7 | 72.1 | 114 | — | MessagePack | slower | yes | 86 |
| jackson | 2.18.3 | 35.7 | 50.1 | 87.0 | 158 | — | JSON — common default | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 45.1 | 79.7 | 134 | 4841 | — | Protocol Buffers | fastest | yes | 93 |
| jsoniter | 0.9.23 | 66.7 | 94.4 | 153 | 14804 | — | JSON — fast writer from Experiment 1 | close | yes | 94 |
| jackson | 2.18.3 | 109 | 142 | 251 | 15546 | — | JSON — common default | slower | yes | 90 |
| msgpack | 0.9.8 | 156 | 139 | 300 | 11031 | — | MessagePack | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 10.1 | 11.5 | 21.7 | real |
| jsoniter | 1 | 11.2 | 11.0 | 22.2 | copied |
| msgpack | 1 | 22.8 | 20.4 | 44.0 | real |
| jackson | 1 | 20.1 | 25.4 | 46.1 | real |
| protobuf | 100 | 17.3 | 38.1 | 56.8 | real |
| jsoniter | 100 | 29.5 | 48.0 | 78.3 | copied |
| jackson | 100 | 48.4 | 95.8 | 147 | real |
| msgpack | 100 | 70.2 | 98.3 | 172 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: `jsoniter`. Time/size front: `protobuf`.

