# Experiments

A laboratory notebook of narrow questions this benchmark can run.

**Read [PLAN.md](PLAN.md) first.** It states every question, why the libraries exist, the exact sample, how we decide, and what we must not claim. It uses ordinary words. It is updated after every experiment.

Each experiment is one question. Edit that folder’s **`experiment.yaml`** to change it (sample, languages, libraries). The sample is shared. Each language run is a subfolder. Combined numbers for a dashboard live in that experiment’s `results.json`.

- Experiment 1: [`01-json-library-bakeoff/`](01-json-library-bakeoff/) · [`results.md`](01-json-library-bakeoff/results.md) · [`results.json`](01-json-library-bakeoff/results.json)
- Experiment 2: [`02-flat-record-formats/`](02-flat-record-formats/) · [`results.md`](02-flat-record-formats/results.md) · [`results.json`](02-flat-record-formats/results.json)
- Preview copies for later experiments: [`samples/`](samples/)

| # | Folder | Status | Question |
|---|--------|--------|----------|
| 1 | [01-json-library-bakeoff](01-json-library-bakeoff/) | **Done** | If we must keep JSON, which Python JSON library is best for one order-like record? |
| 2 | [02-flat-record-formats](02-flat-record-formats/) | **Done** | Ordinary JSON vs MessagePack vs Protocol Buffers on one flat record |
| 3 | — | Planned | How much faster is a Python-only library than one other languages can read? |
| 4 | — | Planned | As a sensor list grows, when is JSON too large? |
| 5 | — | Planned | Avro, Protocol Buffers, and JSON on one event |
| 6 | — | Planned | BSON, Smile, and Ion on one order-like record |
| 7 | — | Planned | FlatBuffers and Cap’n Proto: write time versus read time |
| 8 | — | Planned | YAML, TOML, and XML versus JSON |
| 9 | — | Planned | Size after gzip or zstd |
| 10 | — | Planned | One record versus one hundred |
| 11 | — | Planned | Writing into memory versus writing as if to a file |
| 12 | — | Planned | Is the difference the format, or the library? |
| 13 | — | Planned | Does the ranking stay the same if we change the sample? |

Do **1, then 2, then 3, then 4, then 12, then 13** first. Full reasons live in the plan.
