# Experiment 3 — Does writing to a file change the ranking?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 3). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Only treat **real** stream rows as evidence for a file or socket. **copied** means the library built the full result and then dumped it.

Go, Java, and C++ often have a real stream path. JavaScript has memory only. C and Swift stream rows are copied — they are not in this run.

## How to run

```bash
./experiments/03-memory-vs-stream/run.sh
```

Quick look: [`results.md`](results.md).
