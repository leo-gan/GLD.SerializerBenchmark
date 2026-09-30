# Experiment 2 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/go/logs/go/2026-09-29-184142.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| shamaton/msgpack | 3.2.3 | 0.54 | 0.70 | 1.22 | 124 | 2281 | MessagePack — fast Go writer | fastest | yes | 85 |
| protobuf | 1.36.12 | 0.68 | 0.65 | 1.32 | 50 | 2164 | Protocol Buffers | similar | yes | 83 |
| goccy/go-json | 0.10.6 | 0.67 | 0.99 | 1.66 | 168 | 2397 | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 0.73 | 1.18 | 1.93 | 128 | 2296 | MessagePack | slower | yes | 82 |
| encoding/json | go1.24.13 | 0.81 | 2.86 | 3.70 | 168 | 2397 | JSON — ships with Go | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.12 | 17.9 | 21.4 | 39.4 | 4841 | 2164 | Protocol Buffers | fastest | yes | 91 |
| shamaton/msgpack | 3.2.3 | 21.8 | 25.4 | 47.3 | 12031 | 2281 | MessagePack — fast Go writer | slower | yes | 80 |
| goccy/go-json | 0.10.6 | 24.2 | 35.3 | 60.4 | 16546 | 2397 | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| vmihailenco/msgpack | 5.4.1 | 25.6 | 50.1 | 75.7 | 12457 | 2296 | MessagePack | slower | yes | 89 |
| encoding/json | go1.24.13 | 34.4 | 154 | 189 | 16546 | 2397 | JSON — ships with Go | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 1.42 | 1.37 | 2.88 | copied |
| shamaton/msgpack | 1 | 1.11 | 1.98 | 3.10 | real |
| goccy/go-json | 1 | 1.44 | 2.31 | 3.75 | real |
| vmihailenco/msgpack | 1 | 1.96 | 2.35 | 4.27 | real |
| encoding/json | 1 | 1.80 | 5.27 | 7.13 | real |
| protobuf | 100 | 17.0 | 22.8 | 39.5 | copied |
| goccy/go-json | 100 | 24.2 | 48.4 | 72.2 | real |
| shamaton/msgpack | 100 | 26.4 | 60.2 | 87.4 | real |
| vmihailenco/msgpack | 100 | 39.8 | 48.2 | 88.2 | real |
| encoding/json | 100 | 33.0 | 157 | 190 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `shamaton/msgpack`, `protobuf`. Small gap: —. Time/size front: `shamaton/msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

