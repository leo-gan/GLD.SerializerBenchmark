---
# No in-page title (site header has the product name). Browser tab uses site_name.
hide:
  - navigation
  - toc
  - title
---

Compare **100+** serialization libraries across **nine languages**.

[Open live Dashboard](dashboard/){ .md-button .md-button--primary }
[Start Serialization 101](theory/101/){ .md-button }
[How we measure](analysis/){ .md-button }

<div class="honesty-strip" markdown="1">

**Read numbers carefully.** Prefer **one language** (and one format family). Always note **data type** and **mode**. Cross-language times are directional only.

Full story: [Method](analysis/) · [Methodology](analysis/ANALYSIS_METHODOLOGY/) · [Claims](analysis/CLAIMS_AND_REPLICATION/)

</div>

---

## Pick a path

| You want… | Go here |
|-----------|---------|
| Interactive charts, Pareto trade-offs, compare lab | **[Dashboard](dashboard/)** — scatter, ranking, roster, Compare |
| Vocabulary and judgment (students → production) | **[Learn](theory/101/)** — Serialization 101 → 401 |
| Library inventory for one runtime | **[Languages](c/)** — Overview + **Results** per language |
| How we time, clean, and claim | **[Method](analysis/)** — architecture, modes, metrics |

{ .path-matrix }

### Who each path serves

<ul class="role-routes">
  <li>
    <strong>Student</strong>
    <span>What serialization is; fair charts without drowning in stats.</span>
    <a href="theory/101/">Learn 101</a> · <a href="dashboard/">Dashboard</a>
  </li>
  <li>
    <strong>Integrator</strong>
    <span>Trade-offs for your language and payload shape.</span>
    <a href="dashboard/">Dashboard</a> · <a href="theory/301/">301</a>
  </li>
  <li>
    <strong>Researcher</strong>
    <span>Warmup, filters, replication language for claims.</span>
    <a href="analysis/ANALYSIS_METHODOLOGY/">Methodology</a> · <a href="analysis/CLAIMS_AND_REPLICATION/">Claims</a>
  </li>
  <li>
    <strong>Author</strong>
    <span>Drop in a codec; smoke; A/B against a previous build.</span>
    <a href="analysis/ADDING_A_SERIALIZER/">Add serializer</a> · <a href="theory/401/">401</a>
  </li>
</ul>

---

## Same data · same pipeline

This suite runs the **same data shapes** through serializers in many languages, writes a **shared CSV contract**, and analyzes results with one statistics pipeline. Compare libraries **inside one language**—not a global winner podium.

Example measurement output (Python, `message` data type, 1 instance). Full tables and charts live on each language **Results** page and in the **Dashboard**.

[![Python serialize/deserialize latency distribution for message (n=1)](analysis/plots/violin/python_message@n=1.png){ width="780" }](python/results/)

---

## Languages

Nine runners share the same data types and analysis rules.

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

## Learn the ideas first (optional)

1. [Serialization 101](theory/101/) — what serialization is; three lenses  
2. [Serialization 201](theory/201/) — how formats work under the hood  
3. [Serialization 301](theory/301/) — production judgment  
4. [Serialization 401](theory/401/) — wire formats and labs  

Then return to the **[Dashboard](dashboard/)** with clearer questions.
