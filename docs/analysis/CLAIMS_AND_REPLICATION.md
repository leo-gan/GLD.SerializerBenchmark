# Claims and replication

This page is written for a **first-year university student**. No advanced stats course required.

It answers one practical question:

> **After I look at the Dashboard, what am I allowed to say out loud?**

Different amounts of evidence support different claim strengths. We call those levels **L1**, **L2**, and **L3**.

---

## Learning goals

By the end of this page you should be able to:

1. Tell whether a published Dashboard run is a **single-session snapshot** (L1).
2. Explain why repeating the suite on the **same machine** (L2) is stronger than one lucky run.
3. Explain why **different machines** (L3) are needed before you talk about “generalizes across hardware.”
4. Know the command that aggregates several CSVs for one language.

---

## Everyday analogy

Imagine you want to know which car is fastest.

| Evidence | Everyday claim you may make |
|----------|-----------------------------|
| **One race, one track, one day** | “On this track, today, car A finished first.” |
| **Several races, same track** | “Across repeated races on this track, car A usually wins.” |
| **Races on several tracks** | “Across this set of tracks, car A tends to win.” |

You still should **not** claim “fastest car in the world on every road forever.” That would need far more evidence than this suite produces.

---

## Claim levels (L1 / L2 / L3)

| Level | Evidence | Allowed claim language | What this suite ships by default |
|-------|----------|------------------------|----------------------------------|
| **L1 — single session** | One full (or smoke) run on **one host** | “On **this machine**, in **this session**…” | **Dashboard** Overview (run chrome + current Samples policy). Packed from `logs/<lang>/<ts>.csv` + sidecar via `dashboard/scripts/sync-data.py`. |
| **L2 — multi-session, same host** | ≥ **3** timestamped runs with the **same** `machine_id` | “Stable across **repeated sessions on this host**…” | Optional: `analyze-benchmarks --multi-session …` |
| **L3 — multi-machine** | ≥ **2** distinct `machine_id` values | “Consistent across **these machines**…” (still not “all hardware”) | Optional multi-session report with different hosts |

Default Dashboard packed latest is claim level **L1**. It does **not** claim multi-machine generalization.

### How `machine_id` works

Each run can write a sidecar next to the CSV:

```text
logs/<lang>/YYYY-MM-DD-HHMMSS.csv
logs/<lang>/YYYY-MM-DD-HHMMSS.configs.json
```

Inside `environment` the analysis package stores a short **`machine_id`** fingerprint (hash of CPU model, architecture, OS, core count, and hostname material). It is **not** a security identifier. It is only enough to tell “same host class / same box” apart when you merge sessions.

You may also see `claim_level_hint: L1_single_session` on a single capture, and optional `cpu_governor` on Linux when `/sys` is readable.

---

## What L1 is good for (and what it is not)

**Good for:**

- Choosing among libraries **inside one language** on hardware like yours.
- Spotting huge gaps (for example 10× slower), not hair-thin ties.
- Pairing with effect sizes and confidence intervals on **that** session.

**Not good for:**

- “Library X is the fastest serializer on Earth.”
- Treating one CI runner’s numbers as eternal truth after a noisy day.
- Cross-language absolute latency races (different runtimes and GCs).

---

## How to collect L2 evidence (same host)

1. Run a full matrix (or the language you care about) **three or more times**, on a quiet machine if you can:
   ```bash
   ./scripts/run-all-benchmarks.sh -m full -l python
   # wait / cool down, then again…
   ./scripts/run-all-benchmarks.sh -m full -l python
   ./scripts/run-all-benchmarks.sh -m full -l python
   ```
2. List stems:
   ```bash
   analyze-benchmarks --list -l python
   ```
3. Aggregate:
   ```bash
   analyze-benchmarks --multi-session python:STEM1 --multi-session python:STEM2 --multi-session python:STEM3
   # or commas / LANG=stem form:
   analyze-benchmarks --multi-session python=STEM1,python=STEM2,python=STEM3
   ```
4. Read:
   - `reports/multi_session_python.json` — machine ids, claim_level heuristic, per-group medians across sessions, rank stability
   - `reports/multi_session_python.md` — short human summary

The report’s `claim_level` field is a **heuristic**:

- fewer than 3 sessions → `L1_single_session`
- ≥3 sessions, **exactly one known** `machine_id` → `L2_multi_session_same_host`
- ≥3 sessions, **no** machine ids in sidecars → `L2_multi_session_host_unknown` (repeat runs, host not verified)
- ≥2 distinct machine ids → `L3_multi_machine`

Missing sidecars never invent L3. Prefer re-running so each CSV has a `*.configs.json` with `machine_id`.

---

## How to collect L3 evidence (several machines)

Repeat full runs on **different hosts**, copy the CSVs + `*.configs.json` sidecars into one analysis machine (or point `--logs-root` at a shared tree), then run the same `--multi-session` command with stems from each host.

Only then is language like “consistent across machines **in this set**” honest. It is still not a survey of all CPUs or cloud instance types.

---

## Research-mode soft checks (optional)

For publication-oriented L2/L3 work, prefer:

- Linux CPU governor **performance** (when you control the host)
- A quiet machine (no heavy parallel builds)
- Fixed library versions (the CSV already records `SerializerVersion`)

Set `BENCHMARK_RESEARCH=1` and run:

```bash
./scripts/check-research-env.sh
```

This script **warns**; it does **not** fail CI smokes. Isolation features like `isolcpus` are documented, not enforced.

---

## Ranks on a single Dashboard slice

Even inside **one** L1 session, ranking many libraries is like grading many quizzes at once ([multiple comparisons](https://en.wikipedia.org/wiki/Multiple_comparisons_problem "Multiple comparisons problem")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />). [Effect sizes](https://en.wikipedia.org/wiki/Effect_size "Effect size")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> versus the fastest codec are **descriptive / exploratory**. [Holm](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method "Holm–Bonferroni method")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />-adjusted tests only correct inside one (data type × batch size × I/O mode) group. Prefer pairwise A/B for confirmatory library-vs-library checks.

Details: [Analysis methodology — exploratory ranks](ANALYSIS_METHODOLOGY.md#exploratory-ranks).

---

## Related pages

| Page | Why |
|------|-----|
| [Analysis methodology](ANALYSIS_METHODOLOGY.md) | Warmup, outliers, CIs, ranks, multi-session command |
| [Metrics](METRICS.md) | Column definitions including effect-vs-fastest fields |
| [Modes](modes.md) | Smoke vs full vs research run presets |
| [Dashboard](../dashboard/) | Published L1 numbers (run chrome + Details / Compare) |
