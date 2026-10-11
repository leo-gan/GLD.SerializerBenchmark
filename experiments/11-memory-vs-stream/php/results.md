# Experiment 11 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/11-memory-vs-stream/php/logs/php/2026-10-11-150807.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 2.00 | 4.71 | 6.64 | 454 | 231 | JSON | fastest | yes | 99 |
| rybakit-msgpack | v0.9.2 | 9.67 | 12.6 | 22.3 | 335 | 232 | MessagePack | slower | yes | 86 |
| protobuf | v4.33.6+php | 131 | 71.8 | 204 | 160 | 178 | Protocol Buffers | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 2.04 | 4.76 | 6.83 | text_on_stream |
| rybakit-msgpack | 1 | 9.82 | 12.8 | 22.6 | copied |
| protobuf | 1 | 131 | 72.0 | 203 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

