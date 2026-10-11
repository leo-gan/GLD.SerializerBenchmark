# Experiment 1 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/01-json-library-bakeoff/php/logs/php/2026-10-11-145741.csv`
**Language:** php
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| json | 8.3.19 | 1.96 | 4.67 | 6.59 | 454 | 231 | yes | fastest | yes | 99 |
| symfony-json | v7.4.18 | 3.22 | 5.13 | 8.46 | 454 | 231 | yes | slower | yes | 90 |
| jms-json | 3.32.9 | 21.0 | 14.9 | 35.7 | 454 | 231 | yes | slower | yes | 80 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| json | 2.07 | 4.79 | 6.87 | text_on_stream |
| symfony-json | 3.43 | 5.42 | 8.98 | text_on_stream |
| jms-json | 21.3 | 15.4 | 36.8 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `json`.
**Not both slower and larger than another named-JSON library:** `json`.

