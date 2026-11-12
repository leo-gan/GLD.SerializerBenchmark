# Experiment 11 results — php

**Date:** 2026-11-12
**Raw file:** `experiments/03-memory-vs-stream/php/logs/php/2026-11-12-163902.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.92 | 4.53 | 6.39 | 454 | 231 | JSON | fastest | yes | 94 |
| rybakit-msgpack | v0.9.2 | 9.82 | 12.6 | 22.4 | 335 | 232 | MessagePack | slower | yes | 85 |
| protobuf | v4.33.6+php | 132 | 72.3 | 205 | 160 | 178 | Protocol Buffers | slower | yes | 80 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 2.31 | 5.23 | 7.43 | text_on_stream |
| rybakit-msgpack | 1 | 10.4 | 13.5 | 23.9 | copied |
| protobuf | 1 | 136 | 75.6 | 213 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

