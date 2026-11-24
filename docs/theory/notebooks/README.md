# Serialization Course Lab Notebooks

Hands-on Python companions to the [Serialization 101–401](../index.md) curriculum.

> **Note:** Timings and sizes measured inside notebooks are illustrative. The [Dashboard](../../dashboard/index.html) publishes benchmark-runner measurements.

## How to run

### Google Colab

Open any notebook via the **Open in Colab** badge at the top of its companion chapter (links target the `master` branch on GitHub).

### Local

```bash
# from repo root
python -m venv .venv-notebooks && source .venv-notebooks/bin/activate
pip install -r docs/theory/notebooks/requirements-colab.txt jupyter
jupyter lab docs/theory/notebooks/
```

## Layout

| Track | Repository path | Content |
|---|---|---|
| **101** | [`docs/theory/notebooks/101/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/docs/theory/notebooks/101) | Data science and engineering mini labs |
| **201** | [`docs/theory/notebooks/201/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/docs/theory/notebooks/201) | Mechanism labs (encode cost, schema, evolution, dynamic vs. IDL, compression) |
| **301** | [`docs/theory/notebooks/301/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/docs/theory/notebooks/301) | Production decision and boundary notebooks |
| **401** | [`docs/theory/notebooks/401/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/docs/theory/notebooks/401) | Wire-format playground and `MiniUser` encoder lab |
| **Companions** | [Multi-language companions](companions/README.md) | [JavaScript](companions/js/README.md) Node snippets and [Go](companions/go/README.md) / [Rust](companions/rust/README.md) `MiniUser` golden-vector stubs |

## Design rules

1. **Python-first** on Colab; multi-language code appears only as thin companions.
2. Prefer the **standard library** plus a minimal pinned dependency list; do not pull in full suite benchmark runners.
3. Reuse compact teaching schemas (`MiniUser`, small sensor/order records) rather than full suite data types.
4. Link back to the companion chapter; do not fork a second curriculum.
5. Notebook microbenchmarks illustrate mechanisms and never rank libraries globally.

## Colab URL pattern

```text
https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/<level>/<name>.ipynb
```
