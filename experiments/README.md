# Experiments

A laboratory notebook of narrow questions this benchmark can run.

**Read [PLAN.md](PLAN.md) first.** It states every question, why the libraries exist, the exact sample, how we decide, and what we must not claim. It uses ordinary words. It is updated after every experiment.

Each experiment is one question. Edit that folder’s **`experiment.yaml`** to change it (sample, languages, libraries). The sample is shared. Each language run is a subfolder. Combined numbers for a dashboard live in that experiment’s `results.json`.

Plain-language pages: [docs/experiments](../docs/experiments/index.md). The interactive **Dashboard → Experiments** tab lists every folder that has `experiment.yaml`. After you add a folder or refresh `results.json`, run `python3 dashboard/scripts/sync-experiments.py` (also invoked at the end of `sync-data.py`). No dashboard file needs a hardcoded experiment name.

- Experiment 1: [`01-json-library-bakeoff/`](01-json-library-bakeoff/) · [`results.md`](01-json-library-bakeoff/results.md) · [`results.json`](01-json-library-bakeoff/results.json)
- Experiment 2: [`02-flat-record-formats/`](02-flat-record-formats/) · [`results.md`](02-flat-record-formats/results.md) · [`results.json`](02-flat-record-formats/results.json)
- Experiment 3: [`03-one-language-store/`](03-one-language-store/) · [`results.md`](03-one-language-store/results.md) · [`results.json`](03-one-language-store/results.json)
- Experiment 4: [`04-sensor-list-size/`](04-sensor-list-size/) · [`results.md`](04-sensor-list-size/results.md) · [`results.json`](04-sensor-list-size/results.json)
- Experiment 5: [`05-event-log-formats/`](05-event-log-formats/) · [`results.md`](05-event-log-formats/results.md) · [`results.json`](05-event-log-formats/results.json)
- Experiment 6: [`06-document-db-formats/`](06-document-db-formats/) · [`results.md`](06-document-db-formats/results.md) · [`results.json`](06-document-db-formats/results.json)
- Experiment 7: [`07-write-once-read-many/`](07-write-once-read-many/) · [`results.md`](07-write-once-read-many/results.md) · [`results.json`](07-write-once-read-many/results.json)
- Experiment 8: [`08-human-files/`](08-human-files/) · [`results.md`](08-human-files/results.md) · [`results.json`](08-human-files/results.json)
- Experiment 9: [`09-compression-size/`](09-compression-size/) · [`results.md`](09-compression-size/results.md) · [`results.json`](09-compression-size/results.json)
- Experiment 10: [`10-one-vs-hundred/`](10-one-vs-hundred/) · [`results.md`](10-one-vs-hundred/results.md) · [`results.json`](10-one-vs-hundred/results.json)
- Experiment 11: [`11-memory-vs-stream/`](11-memory-vs-stream/) · [`results.md`](11-memory-vs-stream/results.md) · [`results.json`](11-memory-vs-stream/results.json)
- Experiment 12: [`12-format-vs-library/`](12-format-vs-library/) · [`results.md`](12-format-vs-library/results.md) · [`results.json`](12-format-vs-library/results.json)
- Experiment 13: [`13-ranking-accident/`](13-ranking-accident/) · [`results.md`](13-ranking-accident/results.md) · [`results.json`](13-ranking-accident/results.json)
- Preview copies for later experiments: [`samples/`](samples/)

| # | Folder | Status | Question |
|---|--------|--------|----------|
| 1 | [01-json-library-bakeoff](01-json-library-bakeoff/) | **Done** | Which JSON library is fastest? |
| 2 | [02-flat-record-formats](02-flat-record-formats/) | **Done** | Should two services inside the company stop using JSON? |
| 3 | [03-one-language-store](03-one-language-store/) | **Done** | Is a one-language format worth the lock-in? |
| 4 | [04-sensor-list-size](04-sensor-list-size/) | **Done** | When is JSON too big for a sensor? |
| 5 | [05-event-log-formats](05-event-log-formats/) | **Done** | What should we use for an event log? |
| 6 | [06-document-db-formats](06-document-db-formats/) | **Done** | Are database formats better for a normal service call? |
| 7 | [07-write-once-read-many](07-write-once-read-many/) | **Done** | Fast to write, or fast to read? |
| 8 | [08-human-files](08-human-files/) | **Done** | Can we send YAML on the live path? |
| 9 | [09-compression-size](09-compression-size/) | **Done** | Does squeezing the bytes make JSON small enough? |
| 10 | [10-one-vs-hundred](10-one-vs-hundred/) | **Done** | Does one record rank the same as one hundred? |
| 11 | [11-memory-vs-stream](11-memory-vs-stream/) | **Done** | Does writing to a file change the ranking? |
| 12 | [12-format-vs-library](12-format-vs-library/) | **Done** | Is it the format, or the library? |
| 13 | [13-ranking-accident](13-ranking-accident/) | **Done** | Does the ranking stay the same if we change the data? |

Do **1, then 2, then 3, then 4, then 12, then 13** first. Full reasons live in the plan.
