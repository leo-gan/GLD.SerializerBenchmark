# Experiment 9 — Just turn compression on

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 9). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

After gzip or zstd, does JSON stay larger than a dense binary format?

**Only Python records size after gzip / zstd** in this suite. Other language CSVs have no `SizeGzip` column.

**Fix:** add a one-shot gzip/zstd of the written bytes (not timed) to each language runner, matching `python/src/benchmark/runner_v2.py`.

## Who we compare

Python: `orjson` / `json` versus `msgspec-msgpack` and `protobuf` on Sample E (words), Sample C (128 numbers), and Sample B (tiny).

## How to run

```bash
./experiments/09-compression-size/run.sh
```

Quick look: [`results.md`](results.md).
