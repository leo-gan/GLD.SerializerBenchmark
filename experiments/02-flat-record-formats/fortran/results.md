# Experiment 2 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/fortran/logs/fortran/2026-10-11-145944.csv`
**Language:** fortran
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.15 | 0.85 | 1.00 | 44 | 1968 | one language — length-prefixed binary | fastest | yes | 91 |
| json-fortran | 9.3.1 | 12.5 | 13.9 | 26.3 | 172 | 2452 | JSON — json-fortran | slower | yes | 90 |
| fortran-messagepack | 0.3.1 | 14.8 | 16.1 | 31.0 | 120 | 2250 | MessagePack | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 5.32 | 62.9 | 68.5 | 4956 | 1968 | one language — length-prefixed binary | fastest | yes | 96 |
| fortran-messagepack | 0.3.1 | 487 | 671 | 1162 | 12536 | 2250 | MessagePack | slower | yes | 86 |
| json-fortran | 9.3.1 | 632 | 878 | 1515 | 17806 | 2452 | JSON — json-fortran | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

