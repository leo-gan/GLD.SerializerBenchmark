# Experiment 10 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/fortran/logs/fortran/2026-10-11-150801.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.26 | 1.08 | 1.35 | 113 | 1998 | length-prefixed binary | fastest | yes | 94 |
| json-fortran | 9.3.1 | 13.6 | 14.0 | 27.8 | 258 | 2471 | JSON — json-fortran | slower | yes | 92 |
| fortran-messagepack | 0.3.1 | 22.2 | 26.4 | 48.7 | 197 | 2274 | MessagePack | slower | yes | 83 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 20.3 | 78.5 | 99.7 | 12029 | 1998 | length-prefixed binary | fastest | yes | 90 |
| json-fortran | 9.3.1 | 822 | 905 | 1733 | 26647 | 2471 | JSON — json-fortran | slower | yes | 85 |
| fortran-messagepack | 0.3.1 | 1391 | 1896 | 3295 | 20443 | 2274 | MessagePack | slower | yes | 95 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.14 | 0.80 | 0.94 | 44 | 1998 | length-prefixed binary | fastest | yes | 94 |
| json-fortran | 9.3.1 | 11.7 | 12.9 | 24.5 | 172 | 2471 | JSON — json-fortran | slower | yes | 95 |
| fortran-messagepack | 0.3.1 | 13.7 | 14.9 | 28.6 | 120 | 2274 | MessagePack | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 5.37 | 62.1 | 67.2 | 4956 | 1998 | length-prefixed binary | fastest | yes | 86 |
| fortran-messagepack | 0.3.1 | 483 | 682 | 1168 | 12536 | 2274 | MessagePack | slower | yes | 85 |
| json-fortran | 9.3.1 | 623 | 881 | 1525 | 17806 | 2471 | JSON — json-fortran | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample D (event), N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample B (flat), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample B (flat), N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

