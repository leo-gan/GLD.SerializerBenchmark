# Experiment 6 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/06-document-db-formats/php/logs/php/2026-08-28-113608.csv`
**Language:** php
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.77 | 4.17 | 5.97 | 454 | 231 | JSON | fastest | yes | 91 |
| rybakit-msgpack | v0.9.2 | 9.73 | 12.6 | 22.2 | 335 | 232 | MessagePack | slower | yes | 85 |
| cbor | 3.3.1 | 150 | 91.9 | 243 | 339 | 225 | CBOR | slower | yes | 79 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

