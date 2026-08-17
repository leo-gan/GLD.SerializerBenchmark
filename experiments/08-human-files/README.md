# Experiment 8 — Files people edit are not a request path

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 8). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

If YAML or XML is several times slower or much larger than JSON, it stays a **file**. Convert to JSON or Protocol Buffers once, when the process starts.

## Who we compare

- Go: `goccy/go-yaml`, `pelletier/go-toml` versus `goccy/go-json`
- Swift: `Yams`, `TOML`, `XMLCoder` versus `IkigaJSON`
- C#: `YamlDotNet`, `MS XmlSerializer` versus `System.Text.Json`

**Not in this run:** Python, Java, JavaScript, Rust, C, C++. The suite does not register a YAML/TOML/XML pair next to JSON for those languages (except C# extra XML libraries we did not need). Fix: add a YAML writer to those harnesses and list it here.

Some TOML libraries cannot use a bare list as the root. Sample E is a list of words; if TOML fails or wraps a table, that is a limit of TOML, not a timing trick.

## The samples (shared)

Sample A (one order) and Sample E (32 words). Settings: `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/08-human-files/run.sh
```

Quick look: [`results.md`](results.md).
