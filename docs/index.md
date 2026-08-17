---
# No in-page title (site header has the product name). Browser tab uses site_name.
hide:
  - navigation
  - toc
  - title
---

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
| One-question tests (why we do not only use the big table) | **[Experiments](experiments/)** |
| Course on formats and trade-offs (101–401) | **[Learn](theory/101/)** |
| Per-language library lists and result tables | **[Languages](c/)** (sidebar: C, C#, C++, …) |
| Methodology, metrics, how to add a codec | **[Method](analysis/)** |

---

## Same data · same pipeline

Example measurement output (Python, `message` data type, 1 instance). Full tables
and charts live on each language **Results** page and in the **Dashboard**.

[![Python serialize/deserialize latency distribution for message (n=1)](analysis/plots/violin/python_message@n=1.png){ width="780" }](python/results/)

---

## Languages

Nine runners share the same fixtures and analysis rules.

| Language | Serializers |
|----------|------------:|
| [C](c/) · [Results](c/results/) | 20 |
| [C#](c-sharp/) · [Results](c-sharp/results/) | 38 |
| [C++](cpp/) · [Results](cpp/results/) | 27+ |
| [Go](go/) · [Results](go/results/) | 19 |
| [Java](java/) · [Results](java/results/) | 18 |
| [JavaScript](javascript/) · [Results](javascript/results/) | 20 |
| [Python](python/) · [Results](python/results/) | 16 |
| [Rust](rust/) · [Results](rust/results/) | 16 |
| [Swift](swift/) · [Results](swift/results/) | 14 |

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
