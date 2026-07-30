---
hide:
  - navigation
  - toc
title: Home
---

# Multi-Language Serializer Benchmark

**Same data types · same CSV contract · same statistics pipeline.**

Compare **100+** serialization libraries across **nine languages** with fair
within-language rankings—not marketing microbenchmarks.

[Open live Dashboard](dashboard/){ .md-button .md-button--primary }
[Start Serialization 101](theory/101/){ .md-button }
[How we measure](analysis/){ .md-button }

---

## What this project is

This suite runs the **same data shapes** through serializers in many programming
languages, writes a **shared CSV contract**, and analyzes results with one
statistics pipeline. Use it to compare libraries **inside one language** (and
ideally one format family), not to crown a single global winner.

| You want… | Go here |
|-----------|---------|
| Interactive charts, Pareto trade-offs, compare lab | **[Dashboard](dashboard/)** |
| Course on formats and trade-offs (101–401) | **[Learn](theory/101/)** |
| Per-language library lists and result tables | **[Languages](c-sharp/)** (tabs: C#, Python, Rust, …) |
| Methodology, metrics, how to add a codec | **[Method](analysis/)** |

---

## Same data · same pipeline

Example measurement output (Python, `message` data type, 1 instance). Full tables
and charts live on each language **Results** page and in the **Dashboard**.

[![Python serialize/deserialize latency distribution for message (n=1)](analysis/plots/violin/python_message@n=1.png){ width="780" }](python/results/)

---

## Languages

Nine runners share the same fixtures and analysis rules.

| Language | Libraries (approx.) | Pages |
|----------|--------------------:|-------|
| [C#](c-sharp/) | 38 | [Overview](c-sharp/) · [Results](c-sharp/results/) |
| [Python](python/) | 16 | [Overview](python/) · [Results](python/results/) |
| [Rust](rust/) | 16 | [Overview](rust/) · [Results](rust/results/) |
| [C](c/) | 20 | [Overview](c/) · [Results](c/results/) |
| [JavaScript](javascript/) | 20 | [Overview](javascript/) · [Results](javascript/results/) |
| [Go](go/) | 19 | [Overview](go/) · [Results](go/results/) |
| [Java](java/) | 18 | [Overview](java/) · [Results](java/results/) |
| [C++](cpp/) | 27+ | [Overview](cpp/) · [Results](cpp/results/) |
| [Swift](swift/) | 14 | [Overview](swift/) · [Results](swift/results/) |

---

## Learn the ideas first (optional path)

If you are new to serialization, start with the course under **Learn**:

1. [Serialization 101](theory/101/) — what serialization is; three lenses  
2. [Serialization 201](theory/201/) — how formats work under the hood  
3. [Serialization 301](theory/301/) — production judgment  
4. [Serialization 401](theory/401/) — wire formats and labs  

Then return to the **[Dashboard](dashboard/)** with clearer questions.

---

## Honesty rules (short)

- Prefer comparisons **within one language** and one paradigm family.  
- Implementation quality often matters more than the format brand name.  
- Payload shape changes costs a great deal.  
- Numbers on this site are from **this** suite’s runners and analysis—not a universal ranking of all software.

Full methodology: [Method overview](analysis/) · [Analysis methodology](analysis/ANALYSIS_METHODOLOGY/) · [Claims and replication](analysis/CLAIMS_AND_REPLICATION/).
