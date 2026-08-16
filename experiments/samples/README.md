# Preview samples for later experiments

These JSON files are **reading copies** for the plan. They show what later
experiments will measure. They are not rebuilt by a shared script.

When we open an experiment, we add a language folder (for example `python/`)
with its own `save_sample.py`, which writes that run’s official `sample.json`.
Experiment 1 already works that way:
[`../01-json-library-bakeoff/python/save_sample.py`](../01-json-library-bakeoff/python/save_sample.py)
writes the shared [`../01-json-library-bakeoff/sample.json`](../01-json-library-bakeoff/sample.json).

Do not edit these files by hand.

| File | What it is |
|------|------------|
| `message.n1.json` | One flat record (eight fields). Experiment 2. |
| `document.n1.json` | One order-like record (eight line items). Experiment 1 (also copied next to that experiment). |
| `event.n1.json` | One event (id, type, time, producer, four attributes). Experiment 5. |
| `strings.n1.json` | One list of 32 short words. Experiments 8 and 9. |
| `telemetry.points-8.json` | One sensor record with 8 numbers. Experiment 4. |
| `telemetry.points-32.json` | Same shape, 32 numbers (the project default). |
| `telemetry.points-128.json` | Same shape, 128 numbers. |
| `telemetry.points-512.json` | Same shape, 512 numbers. |

When an experiment uses **100 records in one write**, we do not store all 100 here (the file would be long and hard to read). We store **one** record. The runner builds records 0 through 99 with the same builder and seed. To see record number 5, run the script with `--count 6` and look at the last item.
