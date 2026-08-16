# Experiment 1 — If we must keep JSON, which library should we use?

The full argument is in [../PLAN.md](../PLAN.md). This folder is the question. Each language run is a subfolder.

```text
01-json-library-bakeoff/
  experiment.yaml       ← the one file to edit (sample, languages, libraries)
  run.yaml              ← written from experiment.yaml for the benchmark runner
  sample.json           ← shared record (built from experiment.yaml)
  summarize.py          ← rebuild tables and JSON from saved CSVs
  results.md            ← all languages, one page to read
  results.json          ← all languages, for a dashboard
  run.sh                ← run one language or every language
  python/ go/ java/ …   ← one folder per language
```

To change the experiment (which record, which languages, which libraries, how many trials), edit **[`experiment.yaml`](experiment.yaml)** only. A later screen can load and save that file. The field list is described in [`../lib/experiment.config.schema.json`](../lib/experiment.config.schema.json).

Do not compare write times across language folders. Size is the only number that is roughly fair across languages.

## The sample (shared)

One order-like record. Settings: [`experiment.yaml`](experiment.yaml) (`sample:`). Exact value: [`sample.json`](sample.json).

```json
{
  "id": "btimcpxm",
  "status": 4,
  "meta": { "region": "al", "version": 3 },
  "items": [
    { "sku": "ytgl",         "qty": 10, "price_minor": 55613 },
    { "sku": "sdwkhokqmf",   "qty": 38, "price_minor": 2461 },
    { "sku": "gojhtifpuep",  "qty": 97, "price_minor": 90854 },
    { "sku": "zia",          "qty": 79, "price_minor": 67315 },
    { "sku": "pnjt",         "qty": 61, "price_minor": 32619 },
    { "sku": "tftjldmqrott", "qty": 54, "price_minor": 90365 },
    { "sku": "uciperj",      "qty": 78, "price_minor": 60676 },
    { "sku": "eheam",        "qty": 39, "price_minor": 80173 }
  ]
}
```

We write **one** record per call. Rebuild after changing `experiment.yaml`:

```bash
cd analysis
uv run python ../experiments/01-json-library-bakeoff/python/save_sample.py
```

Other language runners build the same *shape* from the same settings and seed. They may not spell the same random words. The file above is the shared record we discuss in the write-up.

## How to run

```bash
./experiments/01-json-library-bakeoff/run.sh            # every language
./experiments/01-json-library-bakeoff/run.sh python go  # some languages
./experiments/01-json-library-bakeoff/python/run.sh     # one language
```

Each run writes a CSV under `<language>/logs/` and refreshes that language’s `results.json` and `results.md`. It does not change the published website tables.

## How a dashboard should read the numbers

For a quick look, open **[`results.md`](results.md)** (every language on one page).

For a dashboard, load **[`results.json`](results.json)** only.

| Field | Meaning |
|-------|---------|
| `schema` | `gld.experiment.results/1` — bump this if the shape changes |
| `experiment_id` | `01-json-library-bakeoff` |
| `sample` | kind, `n`, path to `sample.json` |
| `cleaning` | first trial dropped; stall filter id |
| `languages.<id>.status` | `ok`, `empty`, `missing`, or `error` |
| `languages.<id>.csv` | raw file, so you can rebuild |
| `languages.<id>.rows[]` | one row per library and call style |

Each row has times in **nanoseconds** (`*_ns`) and **microseconds** (`*_us`), size in bytes, gzip size when present, a yes/no for named fields, and how many trials were kept.

To **recalculate** after you change the stall rule or the library list, do not re-time. Run:

```bash
cd analysis
uv run python ../experiments/01-json-library-bakeoff/summarize.py --all
```

That reads the saved CSVs and rewrites every `results.json` / `results.md` plus the combined file.

The main comparison is `io == "memory"` and `writes_named_fields == true`. Stream rows are a side check.

Do not chart a single “winner.” Use `languages.<id>.top_group`:

| Field | Meaning |
|-------|---------|
| `similar` | Not clearly slower than the fastest on this sample (Cliff’s delta below `similar_max`) |
| `close` | A small gap; a different record could change the order |
| `time_size_front` | Not both slower and larger than another named-JSON library |
| `rows[].tier` | `fastest`, `similar`, `close`, or `slower` |

This is not “top 5%.” A 5% time cut-off is tiny when the fastest library is 2 µs and huge when it is 50 µs. Cliff’s delta asks how often the trials are slower, which stays meaningful when the sample is not your production record.

## Who we compare

See the `languages:` list in [`experiment.yaml`](experiment.yaml). `msgspec` is listed but writes a **list of values**, not `{"id": ...}`. Treat it as a different kind of JSON. Set `enabled: false` on a language to skip it without deleting its library list.
