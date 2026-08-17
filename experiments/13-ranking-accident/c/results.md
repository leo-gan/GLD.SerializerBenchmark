# Experiment 13 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/c/logs/c/2026-08-17-104808.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.88 | 1.79 | 5.75 | 460 | — | fast C JSON library | fastest | yes | 93 |
| cJSON | 1.7.18 | 6.58 | 4.76 | 11.1 | 460 | — | small common C JSON library | slower | yes | 95 |
| json-c | 0.15 | 8.74 | 10.5 | 19.3 | 460 | — | system JSON library on many Linux machines | slower | yes | 95 |
| jansson | 2.14 | 10.6 | 9.92 | 20.7 | 460 | — | common C JSON library | slower | yes | 97 |
| parson | 1.5.3 | 17.5 | 6.77 | 24.5 | 460 | — | small C JSON library | slower | yes | 98 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 196 | 150 | 345 | 45951 | — | fast C JSON library | fastest | yes | 96 |
| cJSON | 1.7.18 | 415 | 390 | 805 | 45951 | — | small common C JSON library | slower | yes | 94 |
| json-c | 0.15 | 687 | 807 | 1496 | 45951 | — | system JSON library on many Linux machines | slower | yes | 92 |
| jansson | 2.14 | 756 | 892 | 1647 | 45951 | — | common C JSON library | slower | yes | 95 |
| parson | 1.5.3 | 1459 | 538 | 1998 | 45951 | — | small C JSON library | slower | yes | 96 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.39 | 1.01 | 2.40 | 264 | — | fast C JSON library | fastest | yes | 79 |
| cJSON | 1.7.18 | 3.23 | 2.38 | 5.59 | 264 | — | small common C JSON library | slower | yes | 90 |
| json-c | 0.15 | 3.37 | 4.81 | 8.27 | 264 | — | system JSON library on many Linux machines | slower | yes | 91 |
| parson | 1.5.3 | 5.79 | 3.57 | 9.41 | 264 | — | small C JSON library | slower | yes | 85 |
| jansson | 2.14 | 5.12 | 5.11 | 10.3 | 264 | — | common C JSON library | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 101 | 106 | 207 | 25937 | — | fast C JSON library | fastest | yes | 90 |
| cJSON | 1.7.18 | 224 | 211 | 436 | 25937 | — | small common C JSON library | slower | yes | 92 |
| json-c | 0.15 | 244 | 386 | 632 | 25937 | — | system JSON library on many Linux machines | slower | yes | 89 |
| parson | 1.5.3 | 428 | 275 | 704 | 25937 | — | small C JSON library | slower | yes | 88 |
| jansson | 2.14 | 359 | 452 | 811 | 25937 | — | common C JSON library | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.00 | 0.51 | 1.52 | 171 | — | fast C JSON library | fastest | yes | 91 |
| cJSON | 1.7.18 | 2.49 | 1.34 | 3.84 | 172 | — | small common C JSON library | slower | yes | 93 |
| json-c | 0.15 | 2.25 | 2.90 | 5.17 | 172 | — | system JSON library on many Linux machines | slower | yes | 95 |
| jansson | 2.14 | 2.88 | 3.44 | 6.34 | 172 | — | common C JSON library | slower | yes | 93 |
| parson | 1.5.3 | 4.68 | 1.93 | 6.61 | 172 | — | small C JSON library | slower | yes | 96 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 53.7 | 50.0 | 104 | 16878 | — | fast C JSON library | fastest | yes | 90 |
| cJSON | 1.7.18 | 180 | 117 | 297 | 16910 | — | small common C JSON library | slower | yes | 86 |
| json-c | 0.15 | 174 | 225 | 400 | 16962 | — | system JSON library on many Linux machines | slower | yes | 87 |
| jansson | 2.14 | 210 | 284 | 495 | 16962 | — | common C JSON library | slower | yes | 92 |
| parson | 1.5.3 | 425 | 140 | 566 | 16962 | — | small C JSON library | slower | yes | 91 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.27 | 2.97 | 4.28 | 391 | — | fast C JSON library | fastest | yes | 95 |
| cJSON | 1.7.18 | 3.55 | 5.12 | 8.70 | 391 | — | small common C JSON library | slower | yes | 98 |
| parson | 1.5.3 | 5.03 | 4.92 | 10.6 | 391 | — | small C JSON library | slower | yes | 99 |
| json-c | 0.15 | 4.41 | 6.93 | 11.3 | 391 | — | system JSON library on many Linux machines | slower | yes | 99 |
| jansson | 2.14 | 6.58 | 8.60 | 16.4 | 391 | — | common C JSON library | slower | yes | 97 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 104 | 222 | 326 | 41352 | — | fast C JSON library | fastest | yes | 92 |
| cJSON | 1.7.18 | 214 | 417 | 630 | 41352 | — | small common C JSON library | slower | yes | 89 |
| parson | 1.5.3 | 375 | 386 | 762 | 41352 | — | small C JSON library | slower | yes | 89 |
| json-c | 0.15 | 257 | 521 | 777 | 41352 | — | system JSON library on many Linux machines | slower | yes | 87 |
| jansson | 2.14 | 436 | 708 | 1145 | 41352 | — | common C JSON library | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.83 | 2.03 | 3.77 | 657 | — | fast C JSON library | fastest | yes | 86 |
| json-c | 0.15 | 15.2 | 11.2 | 26.5 | 688 | — | system JSON library on many Linux machines | slower | yes | 84 |
| jansson | 2.14 | 15.2 | 15.6 | 30.9 | 688 | — | common C JSON library | slower | yes | 86 |
| cJSON | 1.7.18 | 27.7 | 6.59 | 34.5 | 666 | — | small common C JSON library | slower | yes | 86 |
| parson | 1.5.3 | 35.2 | 7.87 | 43.2 | 688 | — | small C JSON library | slower | yes | 88 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 138 | 136 | 275 | 66315 | — | fast C JSON library | fastest | yes | 89 |
| json-c | 0.15 | 1354 | 915 | 2273 | 68605 | — | system JSON library on many Linux machines | slower | yes | 92 |
| jansson | 2.14 | 1331 | 1287 | 2623 | 68605 | — | common C JSON library | slower | yes | 90 |
| cJSON | 1.7.18 | 2583 | 572 | 3158 | 66887 | — | small common C JSON library | slower | yes | 94 |
| parson | 1.5.3 | 3317 | 621 | 3933 | 68605 | — | small C JSON library | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| yyjson | 1 | 3.01 | 1.88 | 4.98 | copied |
| cJSON | 1 | 7.16 | 5.91 | 13.0 | copied |
| json-c | 1 | 8.88 | 9.28 | 18.2 | copied |
| jansson | 1 | 11.2 | 10.8 | 22.0 | copied |
| parson | 1 | 18.3 | 8.54 | 26.8 | copied |
| yyjson | 100 | 186 | 144 | 330 | copied |
| cJSON | 100 | 395 | 372 | 770 | copied |
| json-c | 100 | 650 | 765 | 1414 | copied |
| jansson | 100 | 719 | 850 | 1569 | copied |
| parson | 100 | 1389 | 511 | 1901 | copied |
| yyjson | 1 | 1.66 | 1.26 | 2.93 | copied |
| cJSON | 1 | 3.97 | 2.85 | 6.80 | copied |
| json-c | 1 | 3.92 | 4.59 | 8.51 | copied |
| jansson | 1 | 5.74 | 5.57 | 11.3 | copied |
| parson | 1 | 7.01 | 4.35 | 11.4 | copied |
| yyjson | 100 | 102 | 107 | 210 | copied |
| cJSON | 100 | 227 | 213 | 441 | copied |
| json-c | 100 | 246 | 389 | 635 | copied |
| parson | 100 | 432 | 277 | 709 | copied |
| jansson | 100 | 361 | 452 | 813 | copied |
| yyjson | 1 | 1.25 | 0.72 | 1.97 | copied |
| cJSON | 1 | 2.80 | 1.53 | 4.30 | copied |
| json-c | 1 | 2.57 | 2.82 | 5.37 | copied |
| jansson | 1 | 3.18 | 3.61 | 6.78 | copied |
| parson | 1 | 5.20 | 2.18 | 7.40 | copied |
| yyjson | 100 | 55.5 | 52.3 | 108 | copied |
| cJSON | 100 | 185 | 119 | 304 | copied |
| json-c | 100 | 178 | 229 | 407 | copied |
| jansson | 100 | 215 | 292 | 507 | copied |
| parson | 100 | 437 | 142 | 578 | copied |
| yyjson | 1 | 1.76 | 3.10 | 4.92 | copied |
| cJSON | 1 | 4.87 | 6.18 | 11.1 | copied |
| json-c | 1 | 5.32 | 7.71 | 13.0 | copied |
| parson | 1 | 6.90 | 6.62 | 13.5 | copied |
| jansson | 1 | 8.26 | 10.4 | 18.7 | copied |
| yyjson | 100 | 104 | 224 | 328 | copied |
| cJSON | 100 | 216 | 417 | 633 | copied |
| parson | 100 | 379 | 387 | 765 | copied |
| json-c | 100 | 257 | 518 | 776 | copied |
| jansson | 100 | 437 | 708 | 1146 | copied |
| yyjson | 1 | 2.20 | 1.66 | 3.94 | copied |
| json-c | 1 | 14.8 | 10.2 | 25.1 | copied |
| jansson | 1 | 15.2 | 14.8 | 30.3 | copied |
| cJSON | 1 | 27.1 | 7.21 | 34.4 | copied |
| parson | 1 | 33.9 | 8.28 | 42.4 | copied |
| yyjson | 100 | 139 | 137 | 276 | copied |
| json-c | 100 | 1344 | 912 | 2255 | copied |
| jansson | 100 | 1329 | 1279 | 2613 | copied |
| cJSON | 100 | 2550 | 569 | 3118 | copied |
| parson | 100 | 3274 | 618 | 3889 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample A (order), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample D (event), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample D (event), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample B (flat), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample B (flat), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample E (words), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample E (words), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample C (sensor), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

