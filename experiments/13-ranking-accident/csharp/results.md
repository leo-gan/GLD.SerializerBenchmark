# Experiment 13 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/csharp/logs/csharp/2026-08-17-104829.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 8.44 | 5.57 | 14.1 | 440 | — | fast writer | fastest | yes | 82 |
| NetJSON | 1.0.0 | 10.5 | 12.3 | 22.8 | 440 | — | JSON library | slower | yes | 82 |
| Utf8Json | 1.3.7 | 13.0 | 14.7 | 27.4 | 440 | — | fast writer | slower | yes | 81 |
| MS Bond Json | .NET 8.0.28 | 18.9 | 19.4 | 38.1 | 440 | — | Bond JSON protocol | slower | yes | 89 |
| Jil | 2.17.0 | 26.8 | 14.4 | 41.1 | 440 | — | fast writer | slower | yes | 84 |
| System.Text.Json | 8.0.0.0 | 35.9 | 32.3 | 68.3 | 588 | — | ships with modern .NET | slower | yes | 91 |
| ServiceStack Json | 6.11.0 | 40.0 | 36.3 | 76.4 | 440 | — | ServiceStack JSON | slower | yes | 86 |
| Json.Net | 13.0.4 | 39.3 | 51.9 | 90.5 | 560 | — | Newtonsoft.Json | slower | yes | 90 |
| fastJson | 2.4.0.4 | 39.3 | 51.2 | 91.3 | 972 | — | JSON library | slower | yes | 83 |
| Json.Net (Helper) | 13.0.4 | 42.0 | 50.8 | 93.1 | 541 | — | Newtonsoft helper path | slower | yes | 88 |
| MS DataContract Json | .NET 8.0.28 | 34.3 | 62.6 | 97.1 | 588 | — | DataContractJsonSerializer | slower | yes | 86 |
| FsPicklerJson | 5.3.2 | 50.1 | 46.8 | 97.7 | 1024 | — | FsPickler JSON path | slower | yes | 88 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 65.5 | 102 | 171 | 44614 | — | fast writer | fastest | yes | 74 |
| Utf8Json | 1.3.7 | 74.5 | 129 | 210 | 44614 | — | fast writer | slower | yes | 78 |
| NetJSON | 1.0.0 | 114 | 225 | 340 | 44383 | — | JSON library | slower | yes | 76 |
| Jil | 2.17.0 | 250 | 170 | 422 | 44614 | — | fast writer | slower | yes | 76 |
| MS Bond Json | .NET 8.0.28 | 145 | 286 | 433 | 44383 | — | Bond JSON protocol | slower | yes | 76 |
| System.Text.Json | 8.0.0.0 | 172 | 315 | 489 | 59488 | — | ships with modern .NET | slower | yes | 84 |
| FsPicklerJson | 5.3.2 | 337 | 449 | 788 | 66872 | — | FsPickler JSON path | slower | yes | 76 |
| ServiceStack Json | 6.11.0 | 332 | 470 | 797 | 44614 | — | ServiceStack JSON | slower | yes | 72 |
| Json.Net | 13.0.4 | 387 | 604 | 1008 | 58628 | — | Newtonsoft.Json | slower | yes | 76 |
| Json.Net (Helper) | 13.0.4 | 390 | 606 | 1009 | 56520 | — | Newtonsoft helper path | slower | yes | 78 |
| fastJson | 2.4.0.4 | 338 | 799 | 1147 | 57174 | — | JSON library | slower | yes | 77 |
| MS DataContract Json | .NET 8.0.28 | 294 | 1188 | 1501 | 59488 | — | DataContractJsonSerializer | slower | yes | 80 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 5.11 | 2.91 | 8.04 | 254 | — | fast writer | fastest | yes | 87 |
| MS Bond Json | .NET 8.0.28 | 5.50 | 5.24 | 10.8 | 254 | — | Bond JSON protocol | slower | yes | 89 |
| NetJSON | 1.0.0 | 5.43 | 5.39 | 10.8 | 254 | — | JSON library | slower | yes | 93 |
| Utf8Json | 1.3.7 | 7.92 | 5.79 | 13.7 | 254 | — | fast writer | slower | yes | 86 |
| Json.Net (Helper) | 13.0.4 | 10.8 | 9.37 | 19.7 | 304 | — | Newtonsoft helper path | slower | yes | 97 |
| Json.Net | 13.0.4 | 10.7 | 9.31 | 19.9 | 329 | — | Newtonsoft.Json | slower | yes | 94 |
| System.Text.Json | 8.0.0.0 | 11.4 | 9.39 | 20.8 | 340 | — | ships with modern .NET | slower | yes | 95 |
| ServiceStack Json | 6.11.0 | 10.9 | 10.2 | 21.2 | 254 | — | ServiceStack JSON | slower | yes | 95 |
| Jil | 2.17.0 | 13.2 | 8.24 | 21.6 | 254 | — | fast writer | slower | yes | 90 |
| fastJson | 2.4.0.4 | 11.2 | 13.2 | 24.7 | 585 | — | JSON library | slower | yes | 88 |
| MS DataContract Json | .NET 8.0.28 | 12.7 | 20.7 | 33.8 | 340 | — | DataContractJsonSerializer | slower | yes | 89 |
| FsPicklerJson | 5.3.2 | 21.6 | 17.8 | 39.2 | 772 | — | FsPickler JSON path | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 49.3 | 62.6 | 113 | 25456 | — | fast writer | fastest | yes | 83 |
| Utf8Json | 1.3.7 | 56.8 | 95.3 | 153 | 25456 | — | fast writer | slower | yes | 87 |
| NetJSON | 1.0.0 | 61.7 | 115 | 176 | 25456 | — | JSON library | slower | yes | 80 |
| MS Bond Json | .NET 8.0.28 | 79.1 | 142 | 221 | 25456 | — | Bond JSON protocol | slower | yes | 81 |
| Jil | 2.17.0 | 179 | 111 | 291 | 25456 | — | fast writer | slower | yes | 85 |
| System.Text.Json | 8.0.0.0 | 109 | 188 | 297 | 33944 | — | ships with modern .NET | slower | yes | 89 |
| ServiceStack Json | 6.11.0 | 164 | 279 | 447 | 25456 | — | ServiceStack JSON | slower | yes | 87 |
| FsPicklerJson | 5.3.2 | 207 | 273 | 484 | 41324 | — | FsPickler JSON path | slower | yes | 90 |
| Json.Net (Helper) | 13.0.4 | 217 | 291 | 505 | 31360 | — | Newtonsoft helper path | slower | yes | 84 |
| Json.Net | 13.0.4 | 212 | 294 | 511 | 32971 | — | Newtonsoft.Json | slower | yes | 81 |
| fastJson | 2.4.0.4 | 184 | 370 | 554 | 31872 | — | JSON library | slower | yes | 80 |
| MS DataContract Json | .NET 8.0.28 | 154 | 559 | 725 | 33944 | — | DataContractJsonSerializer | slower | yes | 85 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 5.51 | 2.70 | 8.42 | 157 | — | fast writer | fastest | yes | 85 |
| MS Bond Json | .NET 8.0.28 | 4.93 | 5.15 | 10.3 | 142 | — | Bond JSON protocol | slower | yes | 90 |
| NetJSON | 1.0.0 | 4.94 | 5.72 | 10.7 | 142 | — | JSON library | slower | yes | 91 |
| Jil | 2.17.0 | 6.42 | 6.76 | 13.6 | 157 | — | fast writer | slower | yes | 93 |
| Json.Net (Helper) | 13.0.4 | 7.01 | 6.65 | 14.1 | 167 | — | Newtonsoft helper path | slower | yes | 92 |
| Json.Net | 13.0.4 | 7.78 | 7.10 | 14.9 | 172 | — | Newtonsoft.Json | slower | yes | 87 |
| ServiceStack Json | 6.11.0 | 9.53 | 8.24 | 18.0 | 157 | — | ServiceStack JSON | slower | yes | 92 |
| Utf8Json | 1.3.7 | 9.78 | 8.36 | 18.1 | 157 | — | fast writer | slower | yes | 87 |
| fastJson | 2.4.0.4 | 8.26 | 12.5 | 20.7 | 310 | — | JSON library | slower | yes | 85 |
| System.Text.Json | 8.0.0.0 | 16.0 | 11.1 | 27.4 | 212 | — | ships with modern .NET | slower | yes | 97 |
| MS DataContract Json | .NET 8.0.28 | 10.2 | 20.1 | 30.2 | 212 | — | DataContractJsonSerializer | slower | yes | 93 |
| FsPicklerJson | 5.3.2 | 17.4 | 15.2 | 33.1 | 576 | — | FsPickler JSON path | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 53.0 | 41.8 | 95.3 | 15456 | — | fast writer | fastest | yes | 87 |
| NetJSON | 1.0.0 | 51.2 | 93.6 | 144 | 13961 | — | JSON library | slower | yes | 87 |
| MS Bond Json | .NET 8.0.28 | 63.7 | 102 | 167 | 13961 | — | Bond JSON protocol | slower | yes | 90 |
| System.Text.Json | 8.0.0.0 | 82.1 | 109 | 193 | 20608 | — | ships with modern .NET | slower | yes | 90 |
| Jil | 2.17.0 | 64.6 | 135 | 200 | 15456 | — | fast writer | slower | yes | 69 |
| ServiceStack Json | 6.11.0 | 124 | 147 | 276 | 15456 | — | ServiceStack JSON | slower | yes | 94 |
| Json.Net (Helper) | 13.0.4 | 113 | 171 | 283 | 16560 | — | Newtonsoft helper path | slower | yes | 91 |
| Json.Net | 13.0.4 | 114 | 173 | 287 | 16971 | — | Newtonsoft.Json | slower | yes | 91 |
| FsPicklerJson | 5.3.2 | 117 | 163 | 289 | 21060 | — | FsPickler JSON path | slower | yes | 93 |
| fastJson | 2.4.0.4 | 96.8 | 192 | 292 | 16944 | — | JSON library | slower | yes | 90 |
| Utf8Json | 1.3.7 | 114 | 183 | 295 | 15456 | — | fast writer | slower | yes | 69 |
| MS DataContract Json | .NET 8.0.28 | 108 | 373 | 482 | 20608 | — | DataContractJsonSerializer | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 3.44 | 2.79 | 6.44 | 410 | — | fast writer | fastest | yes | 92 |
| NetJSON | 1.0.0 | 4.05 | 4.29 | 8.27 | 410 | — | JSON library | slower | yes | 91 |
| MS Bond Json | .NET 8.0.28 | 4.24 | 4.74 | 9.04 | 410 | — | Bond JSON protocol | slower | yes | 89 |
| Utf8Json | 1.3.7 | 7.10 | 5.92 | 13.2 | 410 | — | fast writer | slower | yes | 90 |
| Json.Net | 13.0.4 | 7.17 | 6.53 | 13.5 | 425 | — | Newtonsoft.Json | slower | yes | 89 |
| Json.Net (Helper) | 13.0.4 | 7.16 | 6.82 | 14.1 | 420 | — | Newtonsoft helper path | slower | yes | 91 |
| ServiceStack Json | 6.11.0 | 6.65 | 7.39 | 14.3 | 410 | — | ServiceStack JSON | slower | yes | 92 |
| System.Text.Json | 8.0.0.0 | 7.85 | 7.65 | 15.6 | 548 | — | ships with modern .NET | slower | yes | 89 |
| Jil | 2.17.0 | 10.5 | 5.21 | 15.9 | 410 | — | fast writer | slower | yes | 91 |
| fastJson | 2.4.0.4 | 8.23 | 9.85 | 17.9 | 563 | — | JSON library | slower | yes | 87 |
| MS DataContract Json | .NET 8.0.28 | 10.0 | 18.6 | 28.4 | 548 | — | DataContractJsonSerializer | slower | yes | 83 |
| FsPicklerJson | 5.3.2 | 17.4 | 16.3 | 34.1 | 960 | — | FsPickler JSON path | slower | yes | 90 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 90.7 | 116 | 209 | 41574 | — | fast writer | fastest | yes | 85 |
| NetJSON | 1.0.0 | 99.5 | 160 | 260 | 41574 | — | JSON library | slower | yes | 90 |
| Utf8Json | 1.3.7 | 103 | 184 | 289 | 41574 | — | fast writer | slower | yes | 84 |
| MS Bond Json | .NET 8.0.28 | 106 | 208 | 317 | 41574 | — | Bond JSON protocol | slower | yes | 86 |
| System.Text.Json | 8.0.0.0 | 143 | 250 | 395 | 55432 | — | ships with modern .NET | slower | yes | 83 |
| fastJson | 2.4.0.4 | 159 | 246 | 405 | 43062 | — | JSON library | slower | yes | 84 |
| Jil | 2.17.0 | 250 | 164 | 414 | 41574 | — | fast writer | slower | yes | 86 |
| Json.Net | 13.0.4 | 193 | 270 | 467 | 43089 | — | Newtonsoft.Json | slower | yes | 87 |
| Json.Net (Helper) | 13.0.4 | 195 | 268 | 467 | 42678 | — | Newtonsoft helper path | slower | yes | 86 |
| ServiceStack Json | 6.11.0 | 118 | 371 | 492 | 41574 | — | ServiceStack JSON | slower | yes | 87 |
| FsPicklerJson | 5.3.2 | 220 | 343 | 565 | 60284 | — | FsPickler JSON path | slower | yes | 86 |
| MS DataContract Json | .NET 8.0.28 | 209 | 761 | 977 | 55432 | — | DataContractJsonSerializer | slower | yes | 86 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| NetJSON | 1.0.0 | 9.57 | 8.52 | 18.0 | 663 | — | JSON library | fastest | yes | 88 |
| MS Bond Json | .NET 8.0.28 | 10.5 | 11.1 | 21.7 | 663 | — | Bond JSON protocol | slower | yes | 83 |
| SpanJson | 4.2.1 | 9.96 | 13.8 | 24.0 | 663 | — | fast writer | slower | yes | 86 |
| Utf8Json | 1.3.7 | 15.1 | 11.8 | 27.1 | 663 | — | fast writer | slower | yes | 87 |
| Json.Net (Helper) | 13.0.4 | 13.6 | 13.6 | 27.2 | 673 | — | Newtonsoft helper path | slower | yes | 88 |
| Json.Net | 13.0.4 | 14.3 | 13.8 | 28.6 | 678 | — | Newtonsoft.Json | slower | yes | 88 |
| Jil | 2.17.0 | 17.3 | 13.6 | 31.4 | 663 | — | fast writer | slower | yes | 90 |
| System.Text.Json | 8.0.0.0 | 18.6 | 16.5 | 35.3 | 884 | — | ships with modern .NET | slower | yes | 89 |
| ServiceStack Json | 6.11.0 | 17.7 | 18.2 | 35.3 | 663 | — | ServiceStack JSON | slower | yes | 87 |
| fastJson | 2.4.0.4 | 16.4 | 20.4 | 36.8 | 818 | — | JSON library | slower | yes | 91 |
| MS DataContract Json | .NET 8.0.28 | 20.0 | 28.5 | 48.7 | 884 | — | DataContractJsonSerializer | slower | yes | 89 |
| FsPicklerJson | 5.3.2 | 30.8 | 28.7 | 59.3 | 1340 | — | FsPickler JSON path | slower | yes | 94 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 390 | 328 | 718 | 65968 | — | fast writer | fastest | yes | 90 |
| Utf8Json | 1.3.7 | 352 | 445 | 809 | 65974 | — | fast writer | slower | yes | 81 |
| NetJSON | 1.0.0 | 430 | 418 | 847 | 65968 | — | JSON library | slower | yes | 85 |
| System.Text.Json | 8.0.0.0 | 447 | 403 | 851 | 87960 | — | ships with modern .NET | slower | yes | 90 |
| Jil | 2.17.0 | 570 | 467 | 1036 | 65968 | — | fast writer | slower | yes | 77 |
| MS Bond Json | .NET 8.0.28 | 471 | 633 | 1110 | 65968 | — | Bond JSON protocol | slower | yes | 74 |
| ServiceStack Json | 6.11.0 | 544 | 620 | 1169 | 65968 | — | ServiceStack JSON | slower | yes | 74 |
| Json.Net | 13.0.4 | 579 | 699 | 1286 | 67483 | — | Newtonsoft.Json | slower | yes | 75 |
| fastJson | 2.4.0.4 | 528 | 756 | 1289 | 67460 | — | JSON library | slower | yes | 75 |
| Json.Net (Helper) | 13.0.4 | 593 | 706 | 1304 | 67072 | — | Newtonsoft helper path | slower | yes | 74 |
| FsPicklerJson | 5.3.2 | 641 | 858 | 1491 | 96944 | — | FsPickler JSON path | slower | yes | 73 |
| MS DataContract Json | .NET 8.0.28 | 627 | 1328 | 1981 | 87960 | — | DataContractJsonSerializer | slower | yes | 76 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 10.8 | 7.94 | 18.8 | text_on_stream |
| NetJSON | 1 | 12.8 | 17.9 | 30.1 | copied |
| Utf8Json | 1 | 14.9 | 18.0 | 33.1 | text_on_stream |
| MS Bond Json | 1 | 19.8 | 24.2 | 44.1 | text_on_stream |
| Jil | 1 | 29.0 | 18.5 | 47.4 | text_on_stream |
| System.Text.Json | 1 | 35.3 | 36.0 | 72.1 | text_on_stream |
| fastJson | 1 | 39.2 | 52.6 | 91.1 | copied |
| ServiceStack Json | 1 | 44.6 | 45.3 | 91.2 | text_on_stream |
| MS DataContract Json | 1 | 35.1 | 64.8 | 99.4 | text_on_stream |
| FsPicklerJson | 1 | 53.3 | 49.5 | 104 | text_on_stream |
| Json.Net | 1 | 46.3 | 61.7 | 108 | text_on_stream |
| Json.Net (Helper) | 1 | 52.3 | 61.5 | 115 | text_on_stream |
| SpanJson | 100 | 67.3 | 109 | 177 | text_on_stream |
| Utf8Json | 100 | 63.1 | 119 | 185 | text_on_stream |
| NetJSON | 100 | 115 | 244 | 363 | copied |
| MS Bond Json | 100 | 161 | 283 | 443 | text_on_stream |
| System.Text.Json | 100 | 162 | 301 | 465 | text_on_stream |
| Jil | 100 | 240 | 244 | 484 | text_on_stream |
| FsPicklerJson | 100 | 307 | 375 | 685 | text_on_stream |
| ServiceStack Json | 100 | 373 | 468 | 850 | text_on_stream |
| Json.Net (Helper) | 100 | 381 | 616 | 1008 | text_on_stream |
| Json.Net | 100 | 427 | 600 | 1036 | text_on_stream |
| fastJson | 100 | 333 | 804 | 1131 | copied |
| MS DataContract Json | 100 | 259 | 1106 | 1378 | text_on_stream |
| SpanJson | 1 | 5.78 | 4.36 | 10.1 | text_on_stream |
| Utf8Json | 1 | 6.74 | 5.38 | 12.1 | text_on_stream |
| NetJSON | 1 | 5.80 | 6.38 | 12.2 | copied |
| MS Bond Json | 1 | 5.93 | 6.53 | 12.6 | text_on_stream |
| System.Text.Json | 1 | 11.0 | 9.56 | 20.3 | text_on_stream |
| Json.Net | 1 | 11.0 | 10.1 | 21.2 | text_on_stream |
| Jil | 1 | 12.1 | 9.82 | 22.0 | text_on_stream |
| ServiceStack Json | 1 | 11.8 | 11.7 | 23.5 | text_on_stream |
| Json.Net (Helper) | 1 | 12.7 | 10.9 | 23.8 | text_on_stream |
| fastJson | 1 | 13.0 | 15.5 | 28.5 | copied |
| MS DataContract Json | 1 | 12.1 | 19.7 | 31.9 | text_on_stream |
| FsPicklerJson | 1 | 22.7 | 17.0 | 39.7 | text_on_stream |
| SpanJson | 100 | 53.0 | 76.9 | 131 | text_on_stream |
| Utf8Json | 100 | 50.6 | 89.9 | 142 | text_on_stream |
| NetJSON | 100 | 64.6 | 129 | 196 | copied |
| MS Bond Json | 100 | 94.9 | 151 | 246 | text_on_stream |
| System.Text.Json | 100 | 109 | 173 | 283 | text_on_stream |
| Jil | 100 | 173 | 146 | 322 | text_on_stream |
| FsPicklerJson | 100 | 193 | 223 | 418 | text_on_stream |
| ServiceStack Json | 100 | 189 | 291 | 480 | text_on_stream |
| Json.Net (Helper) | 100 | 216 | 304 | 524 | text_on_stream |
| Json.Net | 100 | 245 | 302 | 550 | text_on_stream |
| fastJson | 100 | 189 | 384 | 568 | copied |
| MS DataContract Json | 100 | 139 | 520 | 658 | text_on_stream |
| SpanJson | 1 | 5.36 | 4.13 | 9.54 | text_on_stream |
| MS Bond Json | 1 | 6.19 | 6.20 | 12.3 | text_on_stream |
| NetJSON | 1 | 5.78 | 7.01 | 12.8 | copied |
| Jil | 1 | 6.64 | 9.13 | 15.8 | text_on_stream |
| Json.Net | 1 | 8.92 | 8.29 | 17.5 | text_on_stream |
| Json.Net (Helper) | 1 | 9.61 | 9.19 | 18.7 | text_on_stream |
| Utf8Json | 1 | 10.2 | 8.91 | 19.4 | text_on_stream |
| ServiceStack Json | 1 | 11.0 | 10.7 | 21.6 | text_on_stream |
| fastJson | 1 | 9.42 | 14.7 | 24.4 | copied |
| System.Text.Json | 1 | 16.7 | 11.9 | 29.0 | text_on_stream |
| MS DataContract Json | 1 | 11.4 | 22.5 | 34.2 | text_on_stream |
| FsPicklerJson | 1 | 21.1 | 15.5 | 36.5 | text_on_stream |
| SpanJson | 100 | 42.0 | 41.0 | 82.7 | text_on_stream |
| Utf8Json | 100 | 40.3 | 51.3 | 91.7 | text_on_stream |
| System.Text.Json | 100 | 59.6 | 75.8 | 136 | text_on_stream |
| NetJSON | 100 | 53.2 | 87.6 | 140 | copied |
| Jil | 100 | 63.4 | 95.6 | 159 | text_on_stream |
| MS Bond Json | 100 | 63.5 | 97.8 | 161 | text_on_stream |
| FsPicklerJson | 100 | 104 | 120 | 225 | text_on_stream |
| Json.Net | 100 | 113 | 152 | 268 | text_on_stream |
| Json.Net (Helper) | 100 | 107 | 161 | 268 | text_on_stream |
| ServiceStack Json | 100 | 130 | 142 | 274 | text_on_stream |
| fastJson | 100 | 99.3 | 196 | 297 | copied |
| MS DataContract Json | 100 | 93.1 | 326 | 421 | text_on_stream |
| SpanJson | 1 | 4.02 | 3.73 | 7.74 | text_on_stream |
| NetJSON | 1 | 4.96 | 5.36 | 10.3 | copied |
| MS Bond Json | 1 | 5.04 | 5.59 | 10.6 | text_on_stream |
| Utf8Json | 1 | 6.27 | 4.74 | 11.0 | text_on_stream |
| Json.Net | 1 | 8.09 | 7.18 | 15.0 | text_on_stream |
| Json.Net (Helper) | 1 | 8.78 | 7.70 | 16.1 | text_on_stream |
| Jil | 1 | 10.6 | 6.97 | 17.4 | text_on_stream |
| ServiceStack Json | 1 | 7.99 | 9.68 | 17.8 | text_on_stream |
| System.Text.Json | 1 | 9.05 | 8.76 | 17.9 | text_on_stream |
| fastJson | 1 | 9.17 | 11.0 | 20.2 | copied |
| MS DataContract Json | 1 | 10.5 | 17.9 | 28.3 | text_on_stream |
| FsPicklerJson | 1 | 18.5 | 14.9 | 32.8 | text_on_stream |
| SpanJson | 100 | 116 | 147 | 264 | text_on_stream |
| Utf8Json | 100 | 99.0 | 178 | 276 | text_on_stream |
| NetJSON | 100 | 106 | 188 | 295 | copied |
| MS Bond Json | 100 | 122 | 216 | 341 | text_on_stream |
| System.Text.Json | 100 | 134 | 234 | 371 | text_on_stream |
| fastJson | 100 | 167 | 276 | 444 | copied |
| Jil | 100 | 225 | 231 | 459 | text_on_stream |
| FsPicklerJson | 100 | 198 | 280 | 479 | text_on_stream |
| Json.Net | 100 | 212 | 283 | 495 | text_on_stream |
| Json.Net (Helper) | 100 | 203 | 296 | 496 | text_on_stream |
| ServiceStack Json | 100 | 148 | 391 | 541 | text_on_stream |
| MS DataContract Json | 100 | 185 | 725 | 913 | text_on_stream |
| NetJSON | 1 | 9.72 | 9.29 | 18.8 | copied |
| SpanJson | 1 | 10.4 | 6.70 | 18.9 | text_on_stream |
| MS Bond Json | 1 | 9.84 | 11.6 | 21.2 | text_on_stream |
| Utf8Json | 1 | 11.5 | 10.1 | 21.8 | text_on_stream |
| Json.Net | 1 | 13.0 | 13.0 | 26.0 | text_on_stream |
| System.Text.Json | 1 | 14.9 | 12.4 | 27.2 | text_on_stream |
| Json.Net (Helper) | 1 | 14.1 | 13.6 | 28.1 | text_on_stream |
| Jil | 1 | 16.4 | 14.3 | 30.7 | text_on_stream |
| ServiceStack Json | 1 | 15.9 | 14.4 | 30.9 | text_on_stream |
| fastJson | 1 | 15.2 | 19.3 | 34.4 | copied |
| MS DataContract Json | 1 | 15.6 | 25.3 | 41.0 | text_on_stream |
| FsPicklerJson | 1 | 24.3 | 21.8 | 46.4 | text_on_stream |
| SpanJson | 100 | 408 | 241 | 656 | text_on_stream |
| Utf8Json | 100 | 355 | 443 | 802 | text_on_stream |
| System.Text.Json | 100 | 434 | 368 | 808 | text_on_stream |
| NetJSON | 100 | 433 | 448 | 884 | copied |
| MS Bond Json | 100 | 482 | 638 | 1120 | text_on_stream |
| ServiceStack Json | 100 | 581 | 639 | 1221 | text_on_stream |
| Jil | 100 | 574 | 650 | 1228 | text_on_stream |
| Json.Net | 100 | 592 | 714 | 1315 | text_on_stream |
| Json.Net (Helper) | 100 | 599 | 730 | 1335 | text_on_stream |
| fastJson | 100 | 533 | 801 | 1339 | copied |
| FsPicklerJson | 100 | 614 | 770 | 1394 | text_on_stream |
| MS DataContract Json | 100 | 565 | 1229 | 1803 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample A (order), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `NetJSON`.

**sample D (event), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample D (event), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `MS Bond Json`.

**sample B (flat), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `NetJSON`.

**sample E (words), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample E (words), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `NetJSON`. Small gap: —. Time/size front: `NetJSON`.

**sample C (sensor), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

