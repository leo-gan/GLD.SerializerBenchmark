# Serialization course lab notebooks

Hands-on companions to the [Serialization 101–401](https://leo-gan.github.io/GLD.SerializerBenchmark/theory/101/) theory track.

> **Honesty:** timings and sizes here are **illustrative**. Suite language **Results** own harness truth.

## How to run

### Google Colab

Open any notebook via its **Open in Colab** badge (links target the `master` branch on GitHub after merge).

### Local

```bash
# from repo root
python -m venv .venv-notebooks && source .venv-notebooks/bin/activate
pip install -r docs/theory/notebooks/requirements-colab.txt jupyter
jupyter lab docs/theory/notebooks/
```

## Layout

| Phase | Path | Content |
|-------|------|---------|
| **P0** | [`401/`](401/) | Wire-format playground + MiniUser lab |
| **P1** | [`201/`](201/) | Mechanism labs (encode cost, schema, evolution, …) |
| **P2** | [`101/`](101/) | Data science + engineering mini labs |
| **P3** | [`301/`](301/) | Production experiment notebooks |
| **P4** | [`companions/`](companions/) | [JS](companions/js/) Node snippets + [Go](companions/go/) / [Rust](companions/rust/) MiniUser goldens |

## Design rules

1. **Python-first** on Colab; multi-language only as thin companions (P4).
2. Prefer **stdlib** + a few pinned deps; avoid pulling the full suite harness.
3. Reuse teaching schemas (**MiniUser**, small sensor/order records)—not full suite fixtures.
4. Link back to the article; do not fork a second curriculum.
5. Notebook microbenchmarks never rank libraries globally.

## Colab URL pattern

```text
https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/<level>/<name>.ipynb
```
