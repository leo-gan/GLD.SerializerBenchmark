# Experiment 10 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/c/logs/c/2026-09-29-184527.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 0.49 | 0.38 | 0.87 | 121 | 2106 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 94 |
| protobuf-wire | wire-v2 | 0.49 | 0.38 | 0.89 | 121 | 2106 | Protocol Buffers — in-tree wire helper | similar | yes | 90 |
| msgpack-c | 6.0.1 | 0.84 | 1.11 | 1.95 | 197 | 2300 | MessagePack — official C library | slower | yes | 89 |
| mpack | 1.1.1 | 0.67 | 1.33 | 2.01 | 197 | 2300 | MessagePack | slower | yes | 92 |
| yyjson | 0.10.0 | 2.01 | 1.51 | 3.52 | 255 | 2520 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| cJSON | 1.7.19 | 4.63 | 3.77 | 8.41 | 255 | 2526 | JSON — common C library | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 25.0 | 43.1 | 67.8 | 12764 | 2106 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 82 |
| protobuf-wire | wire-v2 | 25.0 | 43.5 | 68.7 | 12764 | 2106 | Protocol Buffers — in-tree wire helper | close | yes | 91 |
| mpack | 1.1.1 | 29.8 | 88.8 | 118 | 20364 | 2300 | MessagePack | slower | yes | 85 |
| msgpack-c | 6.0.1 | 40.3 | 82.0 | 123 | 20364 | 2300 | MessagePack — official C library | slower | yes | 91 |
| yyjson | 0.10.0 | 107 | 131 | 238 | 26164 | 2520 | JSON — fast writer from Experiment 1 | slower | yes | 95 |
| cJSON | 1.7.19 | 236 | 248 | 485 | 26164 | 2526 | JSON — common C library | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 0.18 | 0.21 | 0.39 | 51 | 2106 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 91 |
| protobuf-wire | wire-v2 | 0.19 | 0.27 | 0.45 | 51 | 2106 | Protocol Buffers — in-tree wire helper | slower | yes | 91 |
| msgpack-c | 6.0.1 | 0.53 | 0.81 | 1.36 | 125 | 2300 | MessagePack — official C library | slower | yes | 94 |
| mpack | 1.1.1 | 0.41 | 0.98 | 1.39 | 125 | 2300 | MessagePack | slower | yes | 94 |
| yyjson | 0.10.0 | 1.33 | 0.96 | 2.31 | 170 | 2520 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| cJSON | 1.7.19 | 3.29 | 2.08 | 5.42 | 170 | 2526 | JSON — common C library | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.2 | 6.33 | 40.8 | 47.3 | 4932 | 2106 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 88 |
| protobuf-wire | wire-v2 | 6.18 | 41.3 | 47.7 | 4932 | 2106 | Protocol Buffers — in-tree wire helper | similar | yes | 86 |
| mpack | 1.1.1 | 12.7 | 67.8 | 80.8 | 12295 | 2300 | MessagePack | slower | yes | 90 |
| msgpack-c | 6.0.1 | 21.6 | 61.7 | 83.2 | 12295 | 2300 | MessagePack — official C library | slower | yes | 87 |
| yyjson | 0.10.0 | 61.7 | 73.5 | 135 | 16717 | 2520 | JSON — fast writer from Experiment 1 | slower | yes | 90 |
| cJSON | 1.7.19 | 199 | 156 | 356 | 16741 | 2526 | JSON — common C library | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-c | 1 | 0.72 | 0.57 | 1.30 | copied |
| protobuf-wire | 1 | 0.74 | 0.60 | 1.35 | copied |
| msgpack-c | 1 | 1.07 | 1.43 | 2.51 | copied |
| mpack | 1 | 0.93 | 1.63 | 2.59 | copied |
| yyjson | 1 | 2.88 | 2.14 | 5.03 | real |
| cJSON | 1 | 5.35 | 4.25 | 9.59 | copied |
| protobuf-c | 100 | 25.9 | 43.9 | 70.0 | copied |
| protobuf-wire | 100 | 25.8 | 44.7 | 70.5 | copied |
| mpack | 100 | 31.1 | 89.6 | 121 | copied |
| msgpack-c | 100 | 41.3 | 83.2 | 125 | copied |
| yyjson | 100 | 156 | 164 | 321 | real |
| cJSON | 100 | 238 | 250 | 489 | copied |
| protobuf-c | 1 | 0.46 | 0.44 | 0.90 | copied |
| protobuf-wire | 1 | 0.47 | 0.51 | 1.00 | copied |
| msgpack-c | 1 | 0.85 | 1.08 | 1.94 | copied |
| mpack | 1 | 0.74 | 1.34 | 2.06 | copied |
| yyjson | 1 | 2.28 | 1.53 | 3.81 | real |
| cJSON | 1 | 4.00 | 2.55 | 6.54 | copied |
| protobuf-c | 100 | 7.21 | 41.5 | 48.8 | copied |
| protobuf-wire | 100 | 6.98 | 42.5 | 49.9 | copied |
| mpack | 100 | 13.7 | 67.4 | 81.7 | copied |
| msgpack-c | 100 | 22.4 | 60.3 | 83.2 | copied |
| yyjson | 100 | 106 | 105 | 211 | real |
| cJSON | 100 | 198 | 155 | 352 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `protobuf-c`, `protobuf-wire`. Small gap: —. Time/size front: `protobuf-c`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf-c`. Small gap: `protobuf-wire`. Time/size front: `protobuf-c`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-c`. Small gap: —. Time/size front: `protobuf-c`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf-c`, `protobuf-wire`. Small gap: —. Time/size front: `protobuf-c`.

