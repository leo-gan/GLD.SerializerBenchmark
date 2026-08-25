# Experiment 9 — Does squeezing the bytes make JSON small enough?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 9). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

After gzip or zstd, does JSON stay larger than a dense binary format?

Every language runner now writes `SizeGzip` (and `SizeZstd` when an encoder is present).

## Who we compare

JSON versus MessagePack and Protocol Buffers on Sample E (words), Sample C (128 numbers), and Sample B (tiny). Times stay inside one language. Size after gzip is the cross-language number.

## How to run

```bash
./experiments/09-compression-size/run.sh
```

Quick look: [`results.md`](results.md).
