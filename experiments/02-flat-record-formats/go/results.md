# Experiment 2 results — go

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/go/logs/go/2026-08-16-154159.csv`
**Language:** go
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 0.66 | 0.46 | 1.11 | 50 | — | Protocol Buffers | fastest | yes | 86 |
| shamaton/msgpack | 3.1.2 | 0.71 | 0.68 | 1.38 | 114 | — | MessagePack — fast Go writer | slower | yes | 90 |
| goccy/go-json | 0.10.6 | 0.73 | 0.95 | 1.69 | 168 | — | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 0.68 | 1.12 | 1.78 | 118 | — | MessagePack | slower | yes | 87 |
| encoding/json | go1.24.13 | 0.70 | 2.64 | 3.37 | 168 | — | JSON — ships with Go | slower | yes | 84 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 1.36.11 | 17.0 | 20.9 | 37.8 | 4841 | — | Protocol Buffers | fastest | yes | 86 |
| shamaton/msgpack | 3.1.2 | 21.0 | 27.2 | 48.0 | 11031 | — | MessagePack — fast Go writer | slower | yes | 86 |
| goccy/go-json | 0.10.6 | 25.6 | 35.5 | 61.3 | 16546 | — | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| vmihailenco/msgpack | 5.4.1 | 23.6 | 46.4 | 70.1 | 11457 | — | MessagePack | slower | yes | 84 |
| encoding/json | go1.24.13 | 29.9 | 150 | 181 | 16546 | — | JSON — ships with Go | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 1.16 | 0.91 | 2.15 | copied |
| shamaton/msgpack | 1 | 0.94 | 1.66 | 2.64 | real |
| vmihailenco/msgpack | 1 | 1.33 | 1.71 | 2.98 | real |
| goccy/go-json | 1 | 1.28 | 1.68 | 3.09 | real |
| encoding/json | 1 | 1.15 | 4.37 | 5.52 | real |
| protobuf | 100 | 16.8 | 22.8 | 40.0 | copied |
| goccy/go-json | 100 | 23.0 | 47.2 | 72.8 | real |
| shamaton/msgpack | 100 | 26.9 | 55.2 | 82.3 | real |
| vmihailenco/msgpack | 100 | 39.6 | 45.5 | 85.0 | real |
| encoding/json | 100 | 31.3 | 159 | 194 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

