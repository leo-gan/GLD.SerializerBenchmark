# Experiment 11 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/11-memory-vs-stream/php/logs/php/2026-08-28-113622.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.77 | 4.25 | 6.04 | 454 | 231 | JSON | fastest | yes | 90 |
| rybakit-msgpack | v0.9.2 | 9.80 | 12.6 | 22.5 | 335 | 232 | MessagePack | slower | yes | 78 |
| protobuf | v4.33.6+php | 129 | 71.1 | 201 | 160 | 178 | Protocol Buffers | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.99 | 4.52 | 6.53 | text_on_stream |
| rybakit-msgpack | 1 | 9.97 | 13.1 | 23.1 | copied |
| protobuf | 1 | 132 | 73.1 | 205 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

