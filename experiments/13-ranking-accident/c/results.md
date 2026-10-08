# Experiment 13 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/c/logs/c/2026-09-29-184752.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.53 | 2.25 | 5.79 | 460 | 2687 | fast C JSON library | fastest | yes | 87 |
| cJSON | 1.7.19 | 7.29 | 6.44 | 13.8 | 460 | 2701 | small common C JSON library | slower | yes | 90 |
| json-c | 0.15 | 8.98 | 10.2 | 19.2 | 460 | 2722 | system JSON library on many Linux machines | slower | yes | 90 |
| jansson | 2.15.1 | 11.6 | 10.5 | 22.2 | 460 | 2687 | common C JSON library | slower | yes | 87 |
| parson | 1.5.3 | 18.1 | 8.27 | 26.4 | 460 | 2722 | small C JSON library | slower | yes | 83 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 185 | 153 | 340 | 45951 | 2687 | fast C JSON library | fastest | yes | 81 |
| cJSON | 1.7.19 | 390 | 424 | 818 | 45951 | 2701 | small common C JSON library | slower | yes | 87 |
| json-c | 0.15 | 540 | 754 | 1330 | 45951 | 2722 | system JSON library on many Linux machines | slower | yes | 93 |
| jansson | 2.15.1 | 728 | 843 | 1577 | 45951 | 2687 | common C JSON library | slower | yes | 84 |
| parson | 1.5.3 | 1280 | 520 | 1811 | 45951 | 2722 | small C JSON library | slower | yes | 90 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 2.17 | 1.76 | 3.93 | 264 | 2687 | fast C JSON library | fastest | yes | 93 |
| cJSON | 1.7.19 | 4.41 | 3.64 | 7.98 | 264 | 2701 | small common C JSON library | slower | yes | 92 |
| json-c | 0.15 | 5.04 | 6.80 | 11.8 | 264 | 2722 | system JSON library on many Linux machines | slower | yes | 93 |
| parson | 1.5.3 | 7.34 | 5.00 | 12.5 | 264 | 2722 | small C JSON library | slower | yes | 93 |
| jansson | 2.15.1 | 6.58 | 6.39 | 13.0 | 264 | 2687 | common C JSON library | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 108 | 135 | 243 | 25937 | 2687 | fast C JSON library | fastest | yes | 88 |
| cJSON | 1.7.19 | 238 | 249 | 487 | 25937 | 2701 | small common C JSON library | slower | yes | 90 |
| json-c | 0.15 | 291 | 419 | 708 | 25937 | 2722 | system JSON library on many Linux machines | slower | yes | 84 |
| parson | 1.5.3 | 415 | 306 | 724 | 25937 | 2722 | small C JSON library | slower | yes | 90 |
| jansson | 2.15.1 | 394 | 494 | 897 | 25937 | 2687 | common C JSON library | slower | yes | 87 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.39 | 0.81 | 2.22 | 171 | 2687 | fast C JSON library | fastest | yes | 83 |
| cJSON | 1.7.19 | 3.11 | 2.15 | 5.29 | 172 | 2701 | small common C JSON library | slower | yes | 86 |
| jansson | 2.15.1 | 3.25 | 4.00 | 7.29 | 171 | 2687 | common C JSON library | slower | yes | 84 |
| json-c | 0.15 | 3.29 | 4.10 | 7.32 | 172 | 2722 | system JSON library on many Linux machines | slower | yes | 87 |
| parson | 1.5.3 | 5.43 | 2.47 | 7.86 | 172 | 2722 | small C JSON library | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 57.1 | 69.9 | 128 | 16878 | 2687 | fast C JSON library | fastest | yes | 88 |
| cJSON | 1.7.19 | 188 | 147 | 336 | 16910 | 2701 | small common C JSON library | slower | yes | 92 |
| json-c | 0.15 | 178 | 245 | 423 | 16962 | 2722 | system JSON library on many Linux machines | slower | yes | 89 |
| jansson | 2.15.1 | 190 | 311 | 502 | 16878 | 2687 | common C JSON library | slower | yes | 86 |
| parson | 1.5.3 | 408 | 157 | 565 | 16962 | 2722 | small C JSON library | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.63 | 2.40 | 4.04 | 391 | 2687 | fast C JSON library | fastest | yes | 90 |
| cJSON | 1.7.19 | 3.77 | 5.42 | 9.26 | 391 | 2701 | small common C JSON library | slower | yes | 88 |
| parson | 1.5.3 | 5.48 | 5.06 | 10.6 | 391 | 2722 | small C JSON library | slower | yes | 94 |
| json-c | 0.15 | 4.53 | 7.20 | 11.7 | 391 | 2722 | system JSON library on many Linux machines | slower | yes | 92 |
| jansson | 2.15.1 | 6.59 | 8.02 | 14.6 | 391 | 2687 | common C JSON library | slower | yes | 93 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 110 | 244 | 355 | 41352 | 2687 | fast C JSON library | fastest | yes | 91 |
| cJSON | 1.7.19 | 227 | 472 | 700 | 41352 | 2701 | small common C JSON library | slower | yes | 89 |
| parson | 1.5.3 | 378 | 413 | 797 | 41352 | 2722 | small C JSON library | slower | yes | 87 |
| json-c | 0.15 | 272 | 572 | 847 | 41352 | 2722 | system JSON library on many Linux machines | slower | yes | 89 |
| jansson | 2.15.1 | 477 | 736 | 1211 | 41352 | 2687 | common C JSON library | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 2.40 | 1.91 | 4.31 | 657 | 2687 | fast C JSON library | fastest | yes | 89 |
| jansson | 2.15.1 | 7.77 | 16.9 | 24.7 | 657 | 2687 | common C JSON library | slower | yes | 89 |
| json-c | 0.15 | 15.9 | 12.2 | 28.2 | 688 | 2722 | system JSON library on many Linux machines | slower | yes | 84 |
| cJSON | 1.7.19 | 27.3 | 8.07 | 35.5 | 666 | 2701 | small common C JSON library | slower | yes | 89 |
| parson | 1.5.3 | 34.5 | 8.21 | 42.5 | 688 | 2722 | small C JSON library | slower | yes | 87 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 139 | 155 | 297 | 66315 | 2687 | fast C JSON library | fastest | yes | 88 |
| jansson | 2.15.1 | 460 | 1470 | 1928 | 66315 | 2687 | common C JSON library | slower | yes | 87 |
| json-c | 0.15 | 1282 | 909 | 2193 | 68605 | 2722 | system JSON library on many Linux machines | slower | yes | 94 |
| cJSON | 1.7.19 | 2501 | 621 | 3116 | 66887 | 2701 | small common C JSON library | slower | yes | 95 |
| parson | 1.5.3 | 3258 | 648 | 3908 | 68605 | 2722 | small C JSON library | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| yyjson | 1 | 4.74 | 2.91 | 7.66 | real |
| cJSON | 1 | 8.31 | 8.10 | 16.4 | copied |
| json-c | 1 | 9.91 | 10.5 | 20.4 | copied |
| jansson | 1 | 12.8 | 11.9 | 24.6 | copied |
| parson | 1 | 20.0 | 10.6 | 30.7 | copied |
| yyjson | 100 | 255 | 192 | 450 | real |
| cJSON | 100 | 398 | 433 | 829 | copied |
| json-c | 100 | 533 | 759 | 1310 | copied |
| jansson | 100 | 731 | 856 | 1593 | copied |
| parson | 100 | 1293 | 536 | 1835 | copied |
| yyjson | 1 | 3.21 | 2.35 | 5.55 | real |
| cJSON | 1 | 5.22 | 4.14 | 9.45 | copied |
| json-c | 1 | 5.86 | 7.07 | 13.0 | copied |
| jansson | 1 | 7.38 | 6.83 | 14.2 | copied |
| parson | 1 | 8.52 | 6.07 | 14.5 | copied |
| yyjson | 100 | 166 | 167 | 336 | real |
| cJSON | 100 | 245 | 258 | 505 | copied |
| json-c | 100 | 295 | 428 | 723 | copied |
| parson | 100 | 421 | 315 | 740 | copied |
| jansson | 100 | 401 | 499 | 906 | copied |
| yyjson | 1 | 2.11 | 1.33 | 3.47 | real |
| cJSON | 1 | 3.65 | 2.32 | 5.99 | copied |
| jansson | 1 | 3.68 | 4.16 | 7.88 | copied |
| json-c | 1 | 3.68 | 4.20 | 7.89 | copied |
| parson | 1 | 5.90 | 2.75 | 8.63 | copied |
| yyjson | 100 | 100 | 100 | 202 | real |
| cJSON | 100 | 188 | 147 | 335 | copied |
| json-c | 100 | 175 | 240 | 416 | copied |
| jansson | 100 | 188 | 307 | 495 | copied |
| parson | 100 | 409 | 158 | 568 | copied |
| yyjson | 1 | 2.43 | 3.04 | 5.47 | real |
| cJSON | 1 | 4.90 | 6.32 | 11.2 | copied |
| parson | 1 | 6.65 | 6.24 | 12.9 | copied |
| json-c | 1 | 5.49 | 7.50 | 13.0 | copied |
| jansson | 1 | 7.80 | 8.96 | 16.8 | copied |
| yyjson | 100 | 168 | 267 | 437 | real |
| cJSON | 100 | 220 | 456 | 677 | copied |
| parson | 100 | 372 | 406 | 779 | copied |
| json-c | 100 | 261 | 554 | 815 | copied |
| jansson | 100 | 460 | 708 | 1170 | copied |
| yyjson | 1 | 3.61 | 2.58 | 6.20 | real |
| jansson | 1 | 8.88 | 17.8 | 26.8 | copied |
| json-c | 1 | 16.9 | 12.8 | 29.8 | copied |
| cJSON | 1 | 28.7 | 8.85 | 37.7 | copied |
| parson | 1 | 36.7 | 9.08 | 45.8 | copied |
| yyjson | 100 | 221 | 190 | 413 | real |
| jansson | 100 | 469 | 1482 | 1948 | copied |
| json-c | 100 | 1284 | 917 | 2207 | copied |
| cJSON | 100 | 2494 | 630 | 3125 | copied |
| parson | 100 | 3275 | 655 | 3931 | copied |

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

