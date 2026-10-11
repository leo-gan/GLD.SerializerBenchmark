# Experiment 3 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/03-one-language-store/php/logs/php/2026-10-11-145948.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.42 | 1.93 | 3.33 | 168 | 137 | other languages can read — JSON | fastest | yes | 98 |
| serialize | 8.3.19 | 1.75 | 2.29 | 4.07 | 222 | 162 | one language — PHP serialize | slower | yes | 89 |
| rybakit-msgpack | v0.9.2 | 3.77 | 5.14 | 8.91 | 126 | 127 | other languages can read — MessagePack | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.61 | 2.19 | 3.79 | text_on_stream |
| serialize | 1 | 1.91 | 2.44 | 4.35 | copied |
| rybakit-msgpack | 1 | 4.09 | 5.50 | 9.57 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

