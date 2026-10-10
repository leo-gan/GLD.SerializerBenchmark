# Experiment 13 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/13-ranking-accident/fortran/logs/fortran/2026-10-10-134230.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 45.0 | 41.6 | 86.5 | 505 | 2712 | JSON — jonquil | fastest | yes | 95 |
| json-fortran | 9.3.1 | 39.7 | 50.0 | 89.5 | 473 | 2599 | JSON — json-fortran | similar | yes | 95 |
| rojff | 9f68e5aa4c12 | 55.2 | 59.0 | 116 | 473 | 2623 | JSON — rojff | slower | yes | 92 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 3186 | 3368 | 6609 | 46434 | 2599 | JSON — json-fortran | fastest | yes | 88 |
| rojff | 9f68e5aa4c12 | 6118 | 4401 | 10642 | 46434 | 2623 | JSON — rojff | slower | yes | 93 |
| jonquil | 0.3.2 | 23057 | 3438 | 26629 | 49527 | 2712 | JSON — jonquil | slower | yes | 93 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 20.2 | 21.0 | 40.8 | 258 | 2599 | JSON — json-fortran | fastest | yes | 93 |
| jonquil | 0.3.2 | 26.1 | 22.7 | 48.9 | 273 | 2712 | JSON — jonquil | slower | yes | 83 |
| rojff | 9f68e5aa4c12 | 31.7 | 32.2 | 64.5 | 260 | 2623 | JSON — rojff | slower | yes | 95 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 1188 | 1040 | 2239 | 26647 | 2599 | JSON — json-fortran | fastest | yes | 87 |
| rojff | 9f68e5aa4c12 | 2707 | 2066 | 4825 | 26847 | 2623 | JSON — rojff | slower | yes | 95 |
| jonquil | 0.3.2 | 6482 | 1741 | 8224 | 28040 | 2712 | JSON — jonquil | slower | yes | 94 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 23.3 | 22.2 | 45.7 | 180 | 2712 | JSON — jonquil | fastest | yes | 89 |
| json-fortran | 9.3.1 | 22.0 | 24.3 | 46.5 | 172 | 2599 | JSON — json-fortran | similar | yes | 84 |
| rojff | 9f68e5aa4c12 | 22.6 | 28.3 | 50.8 | 168 | 2623 | JSON — rojff | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 899 | 977 | 1877 | 17806 | 2599 | JSON — json-fortran | fastest | yes | 86 |
| rojff | 9f68e5aa4c12 | 1395 | 1342 | 2727 | 17406 | 2623 | JSON — rojff | slower | yes | 88 |
| jonquil | 0.3.2 | 2258 | 1202 | 3460 | 18509 | 2712 | JSON — jonquil | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 22.3 | 22.6 | 44.8 | 430 | 2599 | JSON — json-fortran | fastest | yes | 97 |
| jonquil | 0.3.2 | 35.8 | 28.6 | 63.6 | 433 | 2712 | JSON — jonquil | slower | yes | 91 |
| rojff | 9f68e5aa4c12 | 29.7 | 33.9 | 64.2 | 430 | 2623 | JSON — rojff | slower | yes | 90 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 1496 | 1261 | 2776 | 42110 | 2599 | JSON — json-fortran | fastest | yes | 91 |
| rojff | 9f68e5aa4c12 | 3220 | 2895 | 6146 | 42110 | 2623 | JSON — rojff | slower | yes | 95 |
| jonquil | 0.3.2 | 11879 | 2723 | 14630 | 42303 | 2712 | JSON — jonquil | slower | yes | 93 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 53.9 | 51.9 | 106 | 722 | 2712 | JSON — jonquil | fastest | yes | 89 |
| json-fortran | 9.3.1 | 66.6 | 44.1 | 111 | 811 | 2599 | JSON — json-fortran | slower | yes | 87 |
| rojff | 9f68e5aa4c12 | 130 | 77.4 | 209 | 685 | 2623 | JSON — rojff | slower | yes | 93 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 6437 | 3797 | 10251 | 82130 | 2599 | JSON — json-fortran | fastest | yes | 84 |
| rojff | 9f68e5aa4c12 | 12847 | 7013 | 19895 | 69558 | 2623 | JSON — rojff | slower | yes | 92 |
| jonquil | 0.3.2 | 22693 | 4758 | 27445 | 73072 | 2712 | JSON — jonquil | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jonquil`, `json-fortran`. Small gap: —. Time/size front: `jonquil`, `json-fortran`.

**sample A (order), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample D (event), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample D (event), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample B (flat), N = 1, memory** — not clearly slower: `jonquil`, `json-fortran`. Small gap: —. Time/size front: `jonquil`, `json-fortran`, `rojff`.

**sample B (flat), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`, `rojff`.

**sample E (words), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample E (words), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

**sample C (sensor), N = 1, memory** — not clearly slower: `jonquil`. Small gap: —. Time/size front: `jonquil`, `rojff`.

**sample C (sensor), N = 100, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`, `rojff`.

