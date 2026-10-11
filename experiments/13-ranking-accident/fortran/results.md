# Experiment 13 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/fortran/logs/fortran/2026-10-11-151230.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 32.9 | 32.0 | 65.2 | 505 | 2712 | JSON — jonquil | fastest | yes | 97 |
| json-fortran | 9.3.1 | 33.6 | 37.4 | 70.8 | 473 | 2599 | JSON — json-fortran | slower | yes | 83 |
| rojff | 9f68e5aa4c12 | 42.0 | 42.4 | 85.0 | 473 | 2623 | JSON — rojff | slower | yes | 93 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 2210 | 2872 | 5143 | 46434 | 2599 | JSON — json-fortran | fastest | yes | 93 |
| rojff | 9f68e5aa4c12 | 3840 | 3635 | 7462 | 46434 | 2623 | JSON — rojff | slower | yes | 93 |
| jonquil | 0.3.2 | 20092 | 2662 | 22662 | 49527 | 2712 | JSON — jonquil | slower | yes | 92 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 11.8 | 13.1 | 24.9 | 258 | 2599 | JSON — json-fortran | fastest | yes | 99 |
| jonquil | 0.3.2 | 17.2 | 15.5 | 32.7 | 273 | 2712 | JSON — jonquil | slower | yes | 99 |
| rojff | 9f68e5aa4c12 | 18.8 | 19.8 | 38.7 | 260 | 2623 | JSON — rojff | slower | yes | 98 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 847 | 927 | 1770 | 26647 | 2599 | JSON — json-fortran | fastest | yes | 83 |
| rojff | 9f68e5aa4c12 | 2037 | 1807 | 3850 | 26847 | 2623 | JSON — rojff | slower | yes | 87 |
| jonquil | 0.3.2 | 5415 | 1381 | 6839 | 28040 | 2712 | JSON — jonquil | slower | yes | 94 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 11.2 | 11.3 | 22.5 | 180 | 2712 | JSON — jonquil | fastest | yes | 90 |
| json-fortran | 9.3.1 | 10.7 | 12.0 | 22.8 | 172 | 2599 | JSON — json-fortran | similar | yes | 84 |
| rojff | 9f68e5aa4c12 | 10.4 | 14.2 | 24.7 | 168 | 2623 | JSON — rojff | slower | yes | 90 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 677 | 870 | 1538 | 17806 | 2599 | JSON — json-fortran | fastest | yes | 91 |
| rojff | 9f68e5aa4c12 | 1037 | 1191 | 2224 | 17406 | 2623 | JSON — rojff | slower | yes | 91 |
| jonquil | 0.3.2 | 1779 | 1009 | 2786 | 18509 | 2712 | JSON — jonquil | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 13.0 | 13.8 | 26.9 | 430 | 2599 | JSON — json-fortran | fastest | yes | 90 |
| rojff | 9f68e5aa4c12 | 15.0 | 23.2 | 38.2 | 430 | 2623 | JSON — rojff | slower | yes | 86 |
| jonquil | 0.3.2 | 23.1 | 21.1 | 44.2 | 433 | 2712 | JSON — jonquil | slower | yes | 87 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 1524 | 1133 | 2635 | 42110 | 2599 | JSON — json-fortran | fastest | yes | 88 |
| rojff | 9f68e5aa4c12 | 2376 | 2527 | 4925 | 42110 | 2623 | JSON — rojff | slower | yes | 91 |
| jonquil | 0.3.2 | 11293 | 2322 | 13672 | 42303 | 2712 | JSON — jonquil | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 44.1 | 43.3 | 87.4 | 722 | 2712 | JSON — jonquil | fastest | yes | 96 |
| json-fortran | 9.3.1 | 54.7 | 36.7 | 91.7 | 811 | 2599 | JSON — json-fortran | slower | yes | 97 |
| rojff | 9f68e5aa4c12 | 110 | 63.1 | 173 | 685 | 2623 | JSON — rojff | slower | yes | 95 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 5102 | 3403 | 8532 | 82130 | 2599 | JSON — json-fortran | fastest | yes | 89 |
| rojff | 9f68e5aa4c12 | 10672 | 6253 | 16969 | 69558 | 2623 | JSON — rojff | slower | yes | 88 |
| jonquil | 0.3.2 | 20877 | 4248 | 25106 | 73072 | 2712 | JSON — jonquil | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jonquil`. Small gap: —. Time/size front: `jonquil`, `json-fortran`.

**sample A (order), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample D (event), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample D (event), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample B (flat), N = 1, memory** — not clearly slower: `jonquil`, `json-fortran`. Small gap: —. Time/size front: `jonquil`, `json-fortran`, `rojff`.

**sample B (flat), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`, `rojff`.

**sample E (words), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample E (words), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample C (sensor), N = 1, memory** — not clearly slower: `jonquil`. Small gap: —. Time/size front: `jonquil`, `rojff`.

**sample C (sensor), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`, `rojff`.

