# Experiment 2 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/02-flat-record-formats/fortran/logs/fortran/2026-10-10-134154.csv`
**Language:** fortran
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.44 | 1.39 | 1.93 | 44 | 1968 | one language — length-prefixed binary | fastest | yes | 95 |
| json-fortran | 9.3.1 | 18.6 | 19.9 | 38.4 | 172 | 2452 | JSON — json-fortran | slower | yes | 90 |
| fortran-messagepack | 0.3.1 | 18.9 | 19.5 | 38.8 | 120 | 2250 | MessagePack | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 5.83 | 72.6 | 78.6 | 4956 | 1968 | one language — length-prefixed binary | fastest | yes | 88 |
| fortran-messagepack | 0.3.1 | 640 | 840 | 1475 | 12536 | 2250 | MessagePack | slower | yes | 91 |
| json-fortran | 9.3.1 | 908 | 983 | 1890 | 17806 | 2452 | JSON — json-fortran | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

