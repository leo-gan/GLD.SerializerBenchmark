# Experiments

A laboratory notebook of narrow questions this benchmark can run.

**Read [PLAN.md](PLAN.md) first.** It states every question, why the libraries exist, the exact sample, how we decide, and what we must not claim.

Each experiment is one question that Overview, Compare, and Compliance do not already hold. Edit that folder’s **`experiment.yaml`** to change it. The sample is shared. Each language run is a subfolder. Combined numbers for a dashboard live in that experiment’s `results.json`.

Plain-language pages: [docs/experiments](../docs/experiments/index.md). The Dashboard lists every folder that has `experiment.yaml`. After you add a folder or refresh `results.json`, run `python3 dashboard/scripts/sync-experiments.py`.

These notebooks were not re-run when Dagr and the graph data set landed. Those rows are on the main Dashboard. `graph` is its own data set. `all@` does not include it.

- Experiment 1: [`01-sensor-list-size/`](01-sensor-list-size/) · [`results.md`](01-sensor-list-size/results.md) · [`results.json`](01-sensor-list-size/results.json)
- Experiment 2: [`02-compression-size/`](02-compression-size/) · [`results.md`](02-compression-size/results.md) · [`results.json`](02-compression-size/results.json)
- Experiment 3: [`03-memory-vs-stream/`](03-memory-vs-stream/) · [`results.md`](03-memory-vs-stream/results.md) · [`results.json`](03-memory-vs-stream/results.json)
- Experiment 4: [`04-fortran-ffi-tax/`](04-fortran-ffi-tax/) · [`results.md`](04-fortran-ffi-tax/results.md) · [`results.json`](04-fortran-ffi-tax/results.json)
- Preview copies: [`samples/`](samples/)

| # | Folder | Status | Question |
|---|--------|--------|----------|
| 1 | [01-sensor-list-size](01-sensor-list-size/) | **Done** | When is JSON too big for a sensor? |
| 2 | [02-compression-size](02-compression-size/) | **Done** | Does squeezing the bytes make JSON small enough? |
| 3 | [03-memory-vs-stream](03-memory-vs-stream/) | **Done** | Does writing to a file change the ranking? |
| 4 | [04-fortran-ffi-tax](04-fortran-ffi-tax/) | **Done** | What does a Fortran call add? |
