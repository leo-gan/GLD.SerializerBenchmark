# Claims and Replication

Empirical benchmark statements must match the evidentiary scope of the underlying measurements.[^1] Every claim quoted from this project should state the controlled experimental cell—**language, standard, data set, data type, and batch size $N$**—together with its **claim level (L1, L2, or L3)**.

## Evidentiary Hierarchy (L1 / L2 / L3)

| Level | Replication Requirement | Valid Claim Scope | Suite Support |
|---|---|---|---|
| **L1 — Single session** | One completed run on one host. | *"On this host and session, under policy `iqr_1.5`, A outperformed B by X%."* | **Default Dashboard** (packed from `logs/<lang>/<ts>.csv` + sidecar via `sync-data.py`). |
| **L2 — Multi-session (same host)** | $\ge 3$ independent timestamped sessions sharing one verified `machine_id`. | *"Across repeated sessions on this host, A consistently outperformed B."* | `analyze-benchmarks --multi-session` (`L2_multi_session_same_host`). |
| **L2 — Host unverified** | $\ge 3$ sessions lacking `machine_id` sidecars. | *"Across repeated sessions (host identity unverified)..."* | `L2_multi_session_host_unknown`; missing sidecars never promote to L3. |
| **L3 — Multi-machine** | $\ge 2$ distinct `machine_id` values across hosts. | *"Consistent across this set of tested machines."* (Still not universal across all hardware.) | `analyze-benchmarks --multi-session` across merged host logs (`L3_multi_machine`). |

Published Dashboard bundles are **L1 single-session snapshots** and do not assert cross-machine generalization.

### Host Identification (`machine_id`)

Sidecars written beside each log (`logs/<lang>/YYYY-MM-DD-HHMMSS.configs.json`) record `environment.machine_id`: a non-cryptographic hash of CPU model, architecture, OS, logical core count, and host metadata, alongside optional Linux `cpu_governor` and `claim_level_hint`. This identifier distinguishes machines during multi-session merges without exposing sensitive host secrets.

## Appropriate vs. Invalid Uses of L1 Evidence

- **Supported by L1:** Screening libraries within one language and standard on comparable hardware; detecting large structural gaps (e.g., $3\times$–$10\times$ speedups or wire-size reductions) corroborated by tight bootstrap CIs and large Cliff's $\delta$; guiding source-level call-site inspection.
- **Not supported by L1:** Universal claims (*"fastest serializer across all hardware"*); resolving narrow ties within measurement noise without repeated sessions; ranking across different programming languages or different wire standards as a single implementation leaderboard.

## Collecting L2 and L3 Evidence

### L2 (Repeated Sessions on One Host)

Execute at least three independent `full` runs on an otherwise idle machine (allowing thermal cooldown between runs), list the generated stems, and aggregate them:

```bash
./scripts/run-all-benchmarks.sh -m full -l python   # repeat ≥ 3 times
analyze-benchmarks --list -l python
analyze-benchmarks \
  --multi-session python:STEM1 \
  --multi-session python:STEM2 \
  --multi-session python:STEM3
```

Aggregation writes `reports/multi_session_<lang>.json` and `.md` containing median-of-session-medians, cross-session IQR, rank stability (fraction of sessions in which each codec placed first), and the heuristic `claim_level`.

### L3 (Multiple Machines)

Collect `full` CSV logs together with their `*.configs.json` sidecars on two or more distinct hosts, place them under a shared `--logs-root`, and run the same `--multi-session` command passing stems from each host.

### Host Environment Checks for Research Runs

For publication-grade L2/L3 studies, pin library versions (logged in `SerializerVersion`), run on a quiet host with the Linux `performance` CPU governor when available, and run the advisory environment check:

```bash
BENCHMARK_RESEARCH=1 ./scripts/check-research-env.sh
```

The script emits warnings only and does not gate CI smoke runs.

## Multi-Way vs. Pairwise Inference

Even within a single L1 session, testing every library against the sample winner across a large leaderboard is an exploratory multiple-comparisons procedure; within-group Holm–Bonferroni adjustment does not control family-wise error across the entire Dashboard. Use pairwise A/B analysis (`--compare-a` / `--compare-b`) for confirmatory two-library or two-version evaluations ([Analysis methodology](ANALYSIS_METHODOLOGY.md#exploratory-ranks)).

## References

[^1]: Georges, A., Buytaert, D., & Eeckhout, L. (2007). "Statistically Rigorous Java Performance Evaluation." *Proceedings of OOPSLA '07*, 57–76. <https://doi.org/10.1145/1297027.1297033>
