# Experiment 11 — Writing into memory versus writing as if to a file

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 11). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Only treat **real** stream rows as evidence for a file or socket. **copied** means the library built the full result and then dumped it.

Go, Java, and C++ often have a real stream path. JavaScript has memory only. C and Swift stream rows are copied — they are not in this run.

## How to run

```bash
./experiments/11-memory-vs-stream/run.sh
```

Quick look: [`results.md`](results.md).
