# Experiment 13 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/csharp/logs/csharp/2026-09-29-184829.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 9.69 | 6.14 | 15.9 | 440 | 2589 | fast writer | fastest | yes | 84 |
| NetJSON | 1.0.0 | 10.8 | 13.4 | 24.3 | 440 | 2568 | JSON library | slower | yes | 93 |
| Utf8Json | 1.3.7 | 14.7 | 15.0 | 29.0 | 440 | 2589 | fast writer | slower | yes | 93 |
| MS Bond Json | .NET 8.0.28 | 19.7 | 20.9 | 41.0 | 440 | 2568 | Bond JSON protocol | slower | yes | 92 |
| Jil | 2.17.0 | 34.3 | 16.8 | 51.7 | 440 | 2614 | fast writer | slower | yes | 99 |
| System.Text.Json | 8.0.0.0 | 37.0 | 33.3 | 71.1 | 440 | 2589 | ships with modern .NET | slower | yes | 96 |
| ServiceStack Json | 6.11.0 | 41.7 | 38.2 | 79.4 | 440 | 2589 | ServiceStack JSON | slower | yes | 88 |
| fastJson | 2.4.0.4 | 39.5 | 53.6 | 93.5 | 972 | 2761 | JSON library | slower | yes | 88 |
| Json.Net (Helper) | 13.0.4 | 46.8 | 53.9 | 99.1 | 541 | 2743 | Newtonsoft helper path | slower | yes | 92 |
| Json.Net | 13.0.4 | 44.1 | 53.9 | 99.5 | 560 | 2756 | Newtonsoft.Json | slower | yes | 91 |
| FsPicklerJson | 5.3.2 | 54.0 | 46.9 | 101 | 768 | 2814 | FsPickler JSON path | slower | yes | 91 |
| MS DataContract Json | .NET 8.0.28 | 37.9 | 66.4 | 104 | 440 | 2589 | DataContractJsonSerializer | slower | yes | 93 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 78.5 | 109 | 194 | 44614 | 2589 | fast writer | fastest | yes | 83 |
| Utf8Json | 1.3.7 | 90.6 | 137 | 241 | 44614 | 2589 | fast writer | slower | yes | 75 |
| NetJSON | 1.0.0 | 131 | 240 | 370 | 44383 | 2568 | JSON library | slower | yes | 73 |
| MS Bond Json | .NET 8.0.28 | 162 | 299 | 463 | 44383 | 2568 | Bond JSON protocol | slower | yes | 78 |
| Jil | 2.17.0 | 279 | 187 | 480 | 44614 | 2614 | fast writer | slower | yes | 72 |
| System.Text.Json | 8.0.0.0 | 201 | 276 | 489 | 44614 | 2589 | ships with modern .NET | slower | yes | 83 |
| FsPicklerJson | 5.3.2 | 365 | 428 | 799 | 50153 | 2814 | FsPickler JSON path | slower | yes | 80 |
| ServiceStack Json | 6.11.0 | 353 | 482 | 838 | 44614 | 2589 | ServiceStack JSON | slower | yes | 79 |
| Json.Net | 13.0.4 | 389 | 596 | 999 | 58628 | 2756 | Newtonsoft.Json | slower | yes | 73 |
| Json.Net (Helper) | 13.0.4 | 422 | 603 | 1028 | 56520 | 2743 | Newtonsoft helper path | slower | yes | 72 |
| fastJson | 2.4.0.4 | 371 | 829 | 1218 | 57174 | 2761 | JSON library | slower | yes | 79 |
| MS DataContract Json | .NET 8.0.28 | 331 | 1147 | 1494 | 44614 | 2589 | DataContractJsonSerializer | slower | yes | 82 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 4.95 | 3.42 | 8.27 | 254 | 2589 | fast writer | fastest | yes | 83 |
| NetJSON | 1.0.0 | 5.13 | 5.15 | 10.5 | 254 | 2568 | JSON library | slower | yes | 80 |
| MS Bond Json | .NET 8.0.28 | 7.09 | 6.48 | 13.2 | 254 | 2568 | Bond JSON protocol | slower | yes | 93 |
| Utf8Json | 1.3.7 | 8.23 | 6.50 | 14.6 | 254 | 2589 | fast writer | slower | yes | 93 |
| Json.Net (Helper) | 13.0.4 | 12.4 | 9.99 | 21.9 | 304 | 2743 | Newtonsoft helper path | slower | yes | 87 |
| System.Text.Json | 8.0.0.0 | 12.4 | 9.90 | 22.2 | 254 | 2589 | ships with modern .NET | slower | yes | 92 |
| ServiceStack Json | 6.11.0 | 11.6 | 10.6 | 22.4 | 254 | 2589 | ServiceStack JSON | slower | yes | 95 |
| Jil | 2.17.0 | 14.9 | 8.58 | 23.5 | 254 | 2614 | fast writer | slower | yes | 91 |
| Json.Net | 13.0.4 | 13.7 | 10.4 | 24.3 | 329 | 2756 | Newtonsoft.Json | slower | yes | 92 |
| fastJson | 2.4.0.4 | 11.9 | 14.4 | 26.2 | 585 | 2761 | JSON library | slower | yes | 92 |
| MS DataContract Json | .NET 8.0.28 | 12.9 | 21.5 | 34.6 | 254 | 2589 | DataContractJsonSerializer | slower | yes | 93 |
| FsPicklerJson | 5.3.2 | 23.7 | 19.6 | 42.9 | 579 | 2814 | FsPickler JSON path | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 51.0 | 65.0 | 117 | 25456 | 2589 | fast writer | fastest | yes | 86 |
| Utf8Json | 1.3.7 | 56.6 | 98.0 | 157 | 25456 | 2589 | fast writer | slower | yes | 89 |
| NetJSON | 1.0.0 | 64.3 | 121 | 186 | 25456 | 2568 | JSON library | slower | yes | 87 |
| MS Bond Json | .NET 8.0.28 | 84.1 | 149 | 235 | 25456 | 2568 | Bond JSON protocol | slower | yes | 87 |
| System.Text.Json | 8.0.0.0 | 103 | 154 | 260 | 25456 | 2589 | ships with modern .NET | slower | yes | 88 |
| Jil | 2.17.0 | 188 | 115 | 307 | 25456 | 2614 | fast writer | slower | yes | 84 |
| ServiceStack Json | 6.11.0 | 171 | 287 | 462 | 25456 | 2589 | ServiceStack JSON | slower | yes | 87 |
| FsPicklerJson | 5.3.2 | 213 | 246 | 463 | 30992 | 2814 | FsPickler JSON path | slower | yes | 88 |
| Json.Net (Helper) | 13.0.4 | 225 | 297 | 526 | 31360 | 2743 | Newtonsoft helper path | slower | yes | 91 |
| Json.Net | 13.0.4 | 220 | 304 | 533 | 32971 | 2756 | Newtonsoft.Json | slower | yes | 92 |
| fastJson | 2.4.0.4 | 197 | 369 | 565 | 31872 | 2761 | JSON library | slower | yes | 85 |
| MS DataContract Json | .NET 8.0.28 | 151 | 515 | 666 | 25456 | 2589 | DataContractJsonSerializer | slower | yes | 89 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 6.50 | 3.23 | 9.93 | 157 | 2589 | fast writer | fastest | yes | 82 |
| NetJSON | 1.0.0 | 4.79 | 5.90 | 10.9 | 142 | 2568 | JSON library | close | yes | 78 |
| MS Bond Json | .NET 8.0.28 | 5.49 | 5.36 | 10.9 | 142 | 2568 | Bond JSON protocol | slower | yes | 84 |
| Jil | 2.17.0 | 6.52 | 7.05 | 13.5 | 157 | 2614 | fast writer | slower | yes | 80 |
| Json.Net | 13.0.4 | 9.38 | 7.84 | 16.8 | 172 | 2756 | Newtonsoft.Json | slower | yes | 85 |
| Json.Net (Helper) | 13.0.4 | 8.87 | 7.83 | 16.9 | 167 | 2743 | Newtonsoft helper path | slower | yes | 87 |
| Utf8Json | 1.3.7 | 9.90 | 8.73 | 18.7 | 157 | 2589 | fast writer | slower | yes | 80 |
| ServiceStack Json | 6.11.0 | 9.57 | 9.34 | 18.9 | 157 | 2589 | ServiceStack JSON | slower | yes | 83 |
| fastJson | 2.4.0.4 | 9.13 | 13.8 | 23.3 | 310 | 2761 | JSON library | slower | yes | 86 |
| System.Text.Json | 8.0.0.0 | 17.9 | 11.8 | 29.9 | 157 | 2589 | ships with modern .NET | slower | yes | 81 |
| MS DataContract Json | .NET 8.0.28 | 12.6 | 24.0 | 37.0 | 157 | 2589 | DataContractJsonSerializer | slower | yes | 87 |
| FsPicklerJson | 5.3.2 | 21.7 | 17.2 | 40.1 | 432 | 2814 | FsPickler JSON path | slower | yes | 86 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 47.8 | 41.2 | 93.0 | 15456 | 2589 | fast writer | fastest | yes | 95 |
| NetJSON | 1.0.0 | 48.3 | 87.6 | 135 | 13961 | 2568 | JSON library | slower | yes | 93 |
| MS Bond Json | .NET 8.0.28 | 61.3 | 99.3 | 161 | 13961 | 2568 | Bond JSON protocol | slower | yes | 97 |
| System.Text.Json | 8.0.0.0 | 75.2 | 86.3 | 162 | 15456 | 2589 | ships with modern .NET | slower | yes | 99 |
| Jil | 2.17.0 | 65.5 | 124 | 188 | 15456 | 2614 | fast writer | slower | yes | 89 |
| ServiceStack Json | 6.11.0 | 115 | 141 | 257 | 15456 | 2589 | ServiceStack JSON | slower | yes | 89 |
| FsPicklerJson | 5.3.2 | 114 | 142 | 258 | 15794 | 2814 | FsPickler JSON path | slower | yes | 93 |
| Json.Net | 13.0.4 | 106 | 160 | 267 | 16971 | 2756 | Newtonsoft.Json | slower | yes | 89 |
| Utf8Json | 1.3.7 | 98.0 | 169 | 268 | 15456 | 2589 | fast writer | slower | yes | 99 |
| Json.Net (Helper) | 13.0.4 | 108 | 161 | 275 | 16560 | 2743 | Newtonsoft helper path | slower | yes | 94 |
| fastJson | 2.4.0.4 | 94.2 | 185 | 280 | 16944 | 2761 | JSON library | slower | yes | 87 |
| MS DataContract Json | .NET 8.0.28 | 103 | 339 | 441 | 15456 | 2589 | DataContractJsonSerializer | slower | yes | 97 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 3.11 | 2.56 | 5.67 | 410 | 2589 | fast writer | fastest | yes | 93 |
| NetJSON | 1.0.0 | 3.84 | 4.06 | 8.05 | 410 | 2568 | JSON library | slower | yes | 94 |
| MS Bond Json | .NET 8.0.28 | 4.70 | 5.00 | 9.56 | 410 | 2568 | Bond JSON protocol | slower | yes | 90 |
| Utf8Json | 1.3.7 | 6.39 | 5.64 | 12.2 | 410 | 2589 | fast writer | slower | yes | 93 |
| ServiceStack Json | 6.11.0 | 6.13 | 6.91 | 13.2 | 410 | 2589 | ServiceStack JSON | slower | yes | 95 |
| Json.Net | 13.0.4 | 7.28 | 6.60 | 13.9 | 425 | 2756 | Newtonsoft.Json | slower | yes | 90 |
| Json.Net (Helper) | 13.0.4 | 7.45 | 7.01 | 14.8 | 420 | 2743 | Newtonsoft helper path | slower | yes | 90 |
| System.Text.Json | 8.0.0.0 | 8.13 | 7.63 | 15.9 | 410 | 2589 | ships with modern .NET | slower | yes | 93 |
| Jil | 2.17.0 | 11.4 | 5.43 | 16.7 | 410 | 2614 | fast writer | slower | yes | 90 |
| fastJson | 2.4.0.4 | 8.57 | 10.0 | 18.6 | 563 | 2761 | JSON library | slower | yes | 93 |
| MS DataContract Json | .NET 8.0.28 | 9.58 | 18.1 | 28.0 | 410 | 2589 | DataContractJsonSerializer | slower | yes | 92 |
| FsPicklerJson | 5.3.2 | 18.3 | 16.5 | 34.3 | 718 | 2814 | FsPickler JSON path | slower | yes | 93 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 92.3 | 119 | 211 | 41574 | 2589 | fast writer | fastest | yes | 89 |
| NetJSON | 1.0.0 | 99.9 | 164 | 264 | 41574 | 2568 | JSON library | slower | yes | 85 |
| Utf8Json | 1.3.7 | 101 | 184 | 287 | 41574 | 2589 | fast writer | slower | yes | 84 |
| MS Bond Json | .NET 8.0.28 | 106 | 208 | 315 | 41574 | 2568 | Bond JSON protocol | slower | yes | 85 |
| System.Text.Json | 8.0.0.0 | 131 | 194 | 329 | 41574 | 2589 | ships with modern .NET | slower | yes | 85 |
| Jil | 2.17.0 | 238 | 164 | 404 | 41574 | 2614 | fast writer | slower | yes | 86 |
| fastJson | 2.4.0.4 | 162 | 247 | 409 | 43062 | 2761 | JSON library | slower | yes | 86 |
| Json.Net | 13.0.4 | 193 | 267 | 460 | 43089 | 2756 | Newtonsoft.Json | slower | yes | 87 |
| Json.Net (Helper) | 13.0.4 | 194 | 265 | 462 | 42678 | 2743 | Newtonsoft helper path | slower | yes | 80 |
| ServiceStack Json | 6.11.0 | 119 | 372 | 495 | 41574 | 2589 | ServiceStack JSON | slower | yes | 87 |
| FsPicklerJson | 5.3.2 | 214 | 295 | 510 | 45212 | 2814 | FsPickler JSON path | slower | yes | 87 |
| MS DataContract Json | .NET 8.0.28 | 200 | 701 | 912 | 41574 | 2589 | DataContractJsonSerializer | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| NetJSON | 1.0.0 | 9.66 | 8.10 | 17.6 | 663 | 2568 | JSON library | fastest | yes | 92 |
| MS Bond Json | .NET 8.0.28 | 10.4 | 11.5 | 21.9 | 663 | 2568 | Bond JSON protocol | slower | yes | 88 |
| SpanJson | 4.2.1 | 10.1 | 12.9 | 23.1 | 663 | 2589 | fast writer | slower | yes | 94 |
| Utf8Json | 1.3.7 | 14.7 | 12.1 | 26.8 | 663 | 2589 | fast writer | slower | yes | 96 |
| Json.Net | 13.0.4 | 14.7 | 14.1 | 28.6 | 678 | 2756 | Newtonsoft.Json | slower | yes | 92 |
| Json.Net (Helper) | 13.0.4 | 15.5 | 14.0 | 29.4 | 673 | 2743 | Newtonsoft helper path | slower | yes | 90 |
| Jil | 2.17.0 | 18.9 | 13.7 | 32.3 | 663 | 2614 | fast writer | slower | yes | 92 |
| System.Text.Json | 8.0.0.0 | 18.9 | 15.5 | 34.7 | 663 | 2589 | ships with modern .NET | slower | yes | 95 |
| fastJson | 2.4.0.4 | 15.8 | 20.5 | 36.3 | 818 | 2761 | JSON library | slower | yes | 97 |
| ServiceStack Json | 6.11.0 | 18.3 | 19.0 | 37.2 | 663 | 2589 | ServiceStack JSON | slower | yes | 97 |
| MS DataContract Json | .NET 8.0.28 | 17.1 | 27.7 | 45.5 | 663 | 2589 | DataContractJsonSerializer | slower | yes | 97 |
| FsPicklerJson | 5.3.2 | 30.9 | 27.9 | 59.5 | 1004 | 2814 | FsPickler JSON path | slower | yes | 95 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 422 | 369 | 781 | 65968 | 2589 | fast writer | fastest | yes | 91 |
| System.Text.Json | 8.0.0.0 | 484 | 325 | 811 | 65968 | 2589 | ships with modern .NET | similar | yes | 91 |
| Utf8Json | 1.3.7 | 378 | 472 | 846 | 65974 | 2589 | fast writer | slower | yes | 88 |
| NetJSON | 1.0.0 | 435 | 421 | 862 | 65968 | 2568 | JSON library | slower | yes | 86 |
| Jil | 2.17.0 | 606 | 508 | 1118 | 65968 | 2614 | fast writer | slower | yes | 78 |
| MS Bond Json | .NET 8.0.28 | 516 | 667 | 1188 | 65968 | 2568 | Bond JSON protocol | slower | yes | 84 |
| ServiceStack Json | 6.11.0 | 587 | 638 | 1240 | 65968 | 2589 | ServiceStack JSON | slower | yes | 76 |
| fastJson | 2.4.0.4 | 557 | 798 | 1356 | 67460 | 2761 | JSON library | slower | yes | 77 |
| Json.Net | 13.0.4 | 636 | 737 | 1356 | 67483 | 2756 | Newtonsoft.Json | slower | yes | 79 |
| Json.Net (Helper) | 13.0.4 | 623 | 749 | 1378 | 67072 | 2743 | Newtonsoft helper path | slower | yes | 81 |
| FsPicklerJson | 5.3.2 | 678 | 841 | 1507 | 72708 | 2814 | FsPickler JSON path | slower | yes | 83 |
| MS DataContract Json | .NET 8.0.28 | 650 | 1275 | 1935 | 65968 | 2589 | DataContractJsonSerializer | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 11.7 | 8.61 | 20.2 | text_on_stream |
| NetJSON | 1 | 12.6 | 19.3 | 31.7 | copied |
| Utf8Json | 1 | 16.2 | 18.6 | 35.6 | text_on_stream |
| Jil | 1 | 31.8 | 19.1 | 50.9 | text_on_stream |
| MS Bond Json | 1 | 21.4 | 30.9 | 52.6 | text_on_stream |
| System.Text.Json | 1 | 41.2 | 39.6 | 82.8 | text_on_stream |
| ServiceStack Json | 1 | 48.1 | 49.4 | 97.7 | text_on_stream |
| fastJson | 1 | 42.5 | 61.2 | 104 | copied |
| MS DataContract Json | 1 | 41.0 | 72.9 | 115 | text_on_stream |
| FsPicklerJson | 1 | 61.6 | 63.4 | 128 | text_on_stream |
| Json.Net | 1 | 56.5 | 81.1 | 136 | text_on_stream |
| Json.Net (Helper) | 1 | 61.9 | 80.6 | 144 | text_on_stream |
| SpanJson | 100 | 66.6 | 111 | 181 | text_on_stream |
| Utf8Json | 100 | 62.6 | 120 | 183 | text_on_stream |
| NetJSON | 100 | 114 | 238 | 356 | copied |
| MS Bond Json | 100 | 164 | 287 | 453 | text_on_stream |
| System.Text.Json | 100 | 161 | 310 | 477 | text_on_stream |
| Jil | 100 | 249 | 238 | 489 | text_on_stream |
| FsPicklerJson | 100 | 307 | 393 | 703 | text_on_stream |
| ServiceStack Json | 100 | 381 | 474 | 855 | text_on_stream |
| Json.Net (Helper) | 100 | 387 | 602 | 998 | text_on_stream |
| Json.Net | 100 | 434 | 594 | 1032 | text_on_stream |
| fastJson | 100 | 348 | 798 | 1159 | copied |
| MS DataContract Json | 100 | 264 | 1091 | 1370 | text_on_stream |
| SpanJson | 1 | 6.45 | 4.06 | 10.6 | text_on_stream |
| Utf8Json | 1 | 7.51 | 6.00 | 13.4 | text_on_stream |
| NetJSON | 1 | 6.87 | 7.24 | 14.1 | copied |
| MS Bond Json | 1 | 7.59 | 9.47 | 17.6 | text_on_stream |
| System.Text.Json | 1 | 13.0 | 10.5 | 23.6 | text_on_stream |
| ServiceStack Json | 1 | 13.4 | 13.0 | 26.2 | text_on_stream |
| Jil | 1 | 16.6 | 11.0 | 29.2 | text_on_stream |
| Json.Net (Helper) | 1 | 17.2 | 13.9 | 30.9 | text_on_stream |
| fastJson | 1 | 14.6 | 17.3 | 31.9 | copied |
| Json.Net | 1 | 18.4 | 14.1 | 32.7 | text_on_stream |
| MS DataContract Json | 1 | 16.1 | 23.2 | 39.0 | text_on_stream |
| FsPicklerJson | 1 | 27.3 | 19.4 | 48.0 | text_on_stream |
| SpanJson | 100 | 51.2 | 74.7 | 126 | text_on_stream |
| Utf8Json | 100 | 49.2 | 88.8 | 140 | text_on_stream |
| NetJSON | 100 | 66.0 | 129 | 195 | copied |
| MS Bond Json | 100 | 93.1 | 148 | 241 | text_on_stream |
| System.Text.Json | 100 | 99.8 | 170 | 271 | text_on_stream |
| Jil | 100 | 177 | 139 | 318 | text_on_stream |
| FsPicklerJson | 100 | 192 | 231 | 426 | text_on_stream |
| ServiceStack Json | 100 | 182 | 280 | 462 | text_on_stream |
| Json.Net (Helper) | 100 | 224 | 303 | 529 | text_on_stream |
| Json.Net | 100 | 248 | 301 | 550 | text_on_stream |
| fastJson | 100 | 185 | 370 | 555 | copied |
| MS DataContract Json | 100 | 133 | 494 | 629 | text_on_stream |
| SpanJson | 1 | 6.00 | 4.36 | 10.4 | text_on_stream |
| MS Bond Json | 1 | 6.14 | 6.76 | 12.9 | text_on_stream |
| NetJSON | 1 | 5.71 | 7.40 | 13.1 | copied |
| Jil | 1 | 6.18 | 8.44 | 14.7 | text_on_stream |
| Utf8Json | 1 | 9.92 | 8.91 | 18.7 | text_on_stream |
| Json.Net | 1 | 11.1 | 9.70 | 19.8 | text_on_stream |
| Json.Net (Helper) | 1 | 10.9 | 10.1 | 20.7 | text_on_stream |
| ServiceStack Json | 1 | 11.3 | 11.6 | 23.6 | text_on_stream |
| fastJson | 1 | 10.2 | 15.5 | 25.8 | copied |
| System.Text.Json | 1 | 18.1 | 11.8 | 29.9 | text_on_stream |
| MS DataContract Json | 1 | 12.4 | 23.7 | 36.4 | text_on_stream |
| FsPicklerJson | 1 | 21.9 | 16.1 | 38.3 | text_on_stream |
| SpanJson | 100 | 41.6 | 40.1 | 82.6 | text_on_stream |
| Utf8Json | 100 | 37.5 | 49.6 | 87.8 | text_on_stream |
| NetJSON | 100 | 50.4 | 84.4 | 135 | copied |
| System.Text.Json | 100 | 60.5 | 74.6 | 138 | text_on_stream |
| Jil | 100 | 64.6 | 92.4 | 158 | text_on_stream |
| MS Bond Json | 100 | 62.7 | 95.8 | 159 | text_on_stream |
| FsPicklerJson | 100 | 103 | 123 | 227 | text_on_stream |
| ServiceStack Json | 100 | 123 | 140 | 264 | text_on_stream |
| Json.Net (Helper) | 100 | 105 | 158 | 265 | text_on_stream |
| Json.Net | 100 | 114 | 149 | 265 | text_on_stream |
| fastJson | 100 | 95.6 | 185 | 281 | copied |
| MS DataContract Json | 100 | 90.5 | 308 | 398 | text_on_stream |
| SpanJson | 1 | 4.50 | 3.63 | 8.13 | text_on_stream |
| NetJSON | 1 | 5.43 | 5.76 | 11.3 | copied |
| MS Bond Json | 1 | 5.78 | 6.38 | 12.1 | text_on_stream |
| Utf8Json | 1 | 6.64 | 5.44 | 12.3 | text_on_stream |
| ServiceStack Json | 1 | 8.27 | 8.93 | 17.4 | text_on_stream |
| Json.Net | 1 | 10.4 | 8.11 | 18.3 | text_on_stream |
| System.Text.Json | 1 | 9.68 | 9.16 | 18.8 | text_on_stream |
| Jil | 1 | 12.9 | 7.39 | 20.2 | text_on_stream |
| Json.Net (Helper) | 1 | 11.5 | 8.92 | 20.4 | text_on_stream |
| fastJson | 1 | 10.2 | 11.7 | 22.0 | copied |
| MS DataContract Json | 1 | 10.5 | 18.4 | 29.0 | text_on_stream |
| FsPicklerJson | 1 | 23.0 | 18.5 | 42.0 | text_on_stream |
| SpanJson | 100 | 115 | 149 | 265 | text_on_stream |
| Utf8Json | 100 | 96.8 | 177 | 274 | text_on_stream |
| NetJSON | 100 | 110 | 182 | 293 | copied |
| MS Bond Json | 100 | 122 | 219 | 342 | text_on_stream |
| System.Text.Json | 100 | 137 | 238 | 378 | text_on_stream |
| fastJson | 100 | 167 | 272 | 443 | copied |
| Jil | 100 | 226 | 221 | 446 | text_on_stream |
| Json.Net | 100 | 210 | 273 | 484 | text_on_stream |
| FsPicklerJson | 100 | 203 | 288 | 491 | text_on_stream |
| Json.Net (Helper) | 100 | 202 | 288 | 497 | text_on_stream |
| ServiceStack Json | 100 | 144 | 372 | 519 | text_on_stream |
| MS DataContract Json | 100 | 179 | 713 | 887 | text_on_stream |
| NetJSON | 1 | 10.2 | 10.0 | 20.0 | copied |
| SpanJson | 1 | 11.9 | 7.41 | 21.0 | text_on_stream |
| MS Bond Json | 1 | 11.7 | 12.9 | 24.4 | text_on_stream |
| Utf8Json | 1 | 13.9 | 11.8 | 25.6 | text_on_stream |
| Json.Net (Helper) | 1 | 17.5 | 15.4 | 33.1 | text_on_stream |
| Json.Net | 1 | 17.9 | 15.8 | 33.6 | text_on_stream |
| System.Text.Json | 1 | 18.4 | 15.5 | 34.5 | text_on_stream |
| ServiceStack Json | 1 | 17.6 | 16.2 | 34.6 | text_on_stream |
| Jil | 1 | 19.7 | 16.1 | 36.6 | text_on_stream |
| fastJson | 1 | 17.7 | 22.9 | 40.6 | copied |
| MS DataContract Json | 1 | 18.4 | 29.8 | 48.5 | text_on_stream |
| FsPicklerJson | 1 | 34.0 | 27.6 | 63.8 | text_on_stream |
| SpanJson | 100 | 448 | 262 | 715 | text_on_stream |
| Utf8Json | 100 | 368 | 452 | 822 | text_on_stream |
| System.Text.Json | 100 | 504 | 388 | 887 | text_on_stream |
| NetJSON | 100 | 473 | 465 | 938 | copied |
| MS Bond Json | 100 | 523 | 681 | 1220 | text_on_stream |
| ServiceStack Json | 100 | 622 | 668 | 1292 | text_on_stream |
| Jil | 100 | 625 | 687 | 1332 | text_on_stream |
| Json.Net | 100 | 646 | 759 | 1420 | text_on_stream |
| fastJson | 100 | 582 | 843 | 1434 | copied |
| Json.Net (Helper) | 100 | 658 | 794 | 1455 | text_on_stream |
| FsPicklerJson | 100 | 658 | 809 | 1474 | text_on_stream |
| MS DataContract Json | 100 | 598 | 1277 | 1870 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample A (order), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `NetJSON`.

**sample D (event), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample D (event), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: `NetJSON`. Time/size front: `SpanJson`, `NetJSON`.

**sample B (flat), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `NetJSON`.

**sample E (words), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample E (words), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `NetJSON`. Small gap: —. Time/size front: `NetJSON`.

**sample C (sensor), N = 100, memory** — not clearly slower: `SpanJson`, `System.Text.Json`. Small gap: —. Time/size front: `SpanJson`.

