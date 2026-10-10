# Experiment 10 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/10-one-vs-hundred/fortran/logs/fortran/2026-10-10-134215.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.80 | 1.99 | 2.89 | 113 | 1998 | length-prefixed binary | fastest | yes | 90 |
| json-fortran | 9.3.1 | 21.4 | 23.1 | 44.7 | 258 | 2471 | JSON — json-fortran | slower | yes | 93 |
| fortran-messagepack | 0.3.1 | 31.9 | 34.6 | 66.9 | 197 | 2274 | MessagePack | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 24.9 | 93.2 | 122 | 12029 | 1998 | length-prefixed binary | fastest | yes | 95 |
| json-fortran | 9.3.1 | 1206 | 1065 | 2284 | 26647 | 2471 | JSON — json-fortran | slower | yes | 86 |
| fortran-messagepack | 0.3.1 | 1954 | 2472 | 4444 | 20443 | 2274 | MessagePack | slower | yes | 92 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.59 | 1.48 | 2.16 | 44 | 1998 | length-prefixed binary | fastest | yes | 82 |
| fortran-messagepack | 0.3.1 | 22.3 | 22.3 | 45.4 | 120 | 2274 | MessagePack | slower | yes | 96 |
| json-fortran | 9.3.1 | 22.2 | 23.7 | 46.3 | 172 | 2471 | JSON — json-fortran | slower | yes | 92 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 6.11 | 73.6 | 81.1 | 4956 | 1998 | length-prefixed binary | fastest | yes | 87 |
| fortran-messagepack | 0.3.1 | 667 | 870 | 1546 | 12536 | 2274 | MessagePack | slower | yes | 86 |
| json-fortran | 9.3.1 | 934 | 1020 | 1962 | 17806 | 2471 | JSON — json-fortran | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample D (event), N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample B (flat), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample B (flat), N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

