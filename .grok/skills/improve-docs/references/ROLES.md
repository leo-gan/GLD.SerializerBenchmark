# Reader roles — profiles and use cases

Canonical roles for **README** and **Dashboard** (and aligned Learn / Method pages).
Derived from `README.md` (“Who it is for”) and `docs/analysis/architecture.md` (“four kinds of reader”).
Common sense overrides any number below when the copy is clearer without it.

---

## Role map (docs ↔ product)

| Role id | README label | Architecture label | Primary surfaces |
|---------|--------------|--------------------|------------------|
| `student` | Computer science students | Student or researcher (trust) | Learn 101–201, Dashboard overview, language Results |
| `integrator` | System integrators | System builder | Dashboard Compare + Pareto, language inventories, test data |
| `researcher` | Researchers | Student or researcher (method) | Method / methodology, modes, stats, History upload |
| `author` | Serializer authors | Library author (+ maintainer path) | Adding a serializer, smoke runs, A/B compare, regression |

Architecture also mentions **maintainer** (add a language). Treat as an advanced path of `author`, not a fifth primary persona for landing copy.

---

## 1. Student (`student`)

### Profile

| Dimension | Typical range |
|-----------|----------------|
| Age | 18–28 (undergrad / early grad); also self-taught career switchers |
| Background | CS, SE, data courses; may know JSON and HTTP, not wire formats |
| Domain knowledge | **Knows:** “JSON is text”, APIs, maybe protobuf name-drop. **Does not know:** schema evolution, native vs adapted stream, Pareto, IQR, warmup, fidelity failures |
| Comprehension | Prefers plain language + one worked example; dense tables without legend lose them |
| Attention span | Short on first visit (30–90s). Catches: big chart, “fastest”, course badge, 60-second try |
| IQ / literacy (heuristic) | Comfortable with college STEM prose; not with stats jargon unglossed |
| Likes | Clear learning path, visuals, “what does this mean?”, small wins |
| Dislikes | Walls of tables first, unexplained acronyms, “just read the CSV”, gated Docker-only starts |
| Trust triggers | Honest limits (“within one language”), named methodology link, open source |

### Typical use cases

1. **First contact:** Land on storefront or README → open Dashboard → stare at scatter without knowing filters.
2. **Course path:** Serialization 101 → 201 → return to Dashboard with better questions.
3. **Assignment:** “Compare two Python serializers on message@n=1” using Results tables or Dashboard Details.
4. **Curiosity:** “Why is MessagePack smaller than JSON?” — wants size vs speed story, not CV.

### Docs obligations

- Progressive disclosure: plain sentence before IQR / P95.
- Default Dashboard filters should “just work” (preferred data type, one language).
- Link Learn from Dashboard; link Dashboard from 101.

---

## 2. System integrator (`integrator`)

### Profile

| Dimension | Typical range |
|-----------|----------------|
| Age | 25–45 |
| Background | Backend, platform, mobile, embedded integration |
| Domain knowledge | **Knows:** latency budgets, payload shapes, language ecosystem. **May not know:** this suite’s mode labels, filter policies, fidelity rules |
| Comprehension | Scans for decision support; wants defaults + advanced knobs |
| Attention | “Show me trade-offs for *my* language and shape.” 2–5 min sessions |
| Likes | Pareto, size/speed, same-language compare, copy markdown into design docs |
| Dislikes | Cross-language “winners”, marketing microbenchmarks, hidden host differences |
| Trust triggers | Same data types / CSV contract, documented I/O modes, honesty about directional cross-lang |

### Typical use cases

1. **Pick a codec:** Language fixed → pick data type close to production → Pareto + ranking.
2. **Design review:** Compare 3–5 candidates vs baseline; export Markdown table.
3. **Payload sensitivity:** Switch message vs document vs telemetry; note size flips.
4. **Private validation:** Run smoke/full locally with tuned catalog; upload stats JSON.

### Docs obligations

- Emphasize **within-language** comparisons.
- Surface Mode (bytes vs stream) and data type prominently.
- Cross-lang path always carries a short directional disclaimer.

---

## 3. Researcher (`researcher`)

### Profile

| Dimension | Typical range |
|-----------|----------------|
| Age | 22–50+ (grad students, industry research, performance engineers) |
| Background | Experimental methods, sometimes formal stats |
| Domain knowledge | **Knows:** bias, warmup, outliers, CIs. **Needs:** suite-specific schedule, filter policies, fidelity, compound modes |
| Comprehension | High for method text; still needs operational “how to reproduce” |
| Attention | Long reads OK if structured; wants claims ↔ evidence map |
| Likes | Methodology, run modes (full/research), History, raw CSV, environment metadata |
| Dislikes | Hidden cleaning of outliers, unreproducible plots, marketing claims without replication path |
| Trust triggers | Warmup exclusion, block shuffle, filter policy IDs, versioned configs |

### Typical use cases

1. **Audit a published number:** Method page → metrics → re-run with same mode/seed.
2. **Sensitivity:** Change filter policy (all / IQR / winsorize); check ranking stability.
3. **Paper / blog:** Cite methodology; use Compare + copy Markdown; attach run id.
4. **Cross-session:** Upload custom stats; compare stems via analysis CLI.

### Docs obligations

- Keep Method linked from Dashboard meta (run id, filter policy).
- Name policies and modes with stable ids; plain labels + tooltips.
- Do not oversell precision; report what the suite actually measures.

---

## 4. Serializer author (`author`)

### Profile

| Dimension | Typical range |
|-----------|----------------|
| Age | 20–50 |
| Background | Library maintainer, contributor, or language-port author |
| Domain knowledge | **Knows:** their API deeply. **May not know:** harness isolation rules, prepare vs timed, stream adaptation traps |
| Comprehension | Code-first; short checklists beat essays |
| Attention | Task-driven: “add codec → smoke → see rank” |
| Likes | Adding-a-serializer guide, smoke mode, A/B compare, regression gate |
| Dislikes | Breaking isolation (shared state), unfair “fresh alloc every call” vs peers, opaque failures |
| Trust triggers | Clear timing rules, error CSV, version field on rows |

### Typical use cases

1. **Add serializer:** Follow ADDING_A_SERIALIZER → smoke → Dashboard Details for new name.
2. **Optimize:** Compare two versions / stems; check fidelity and size unchanged.
3. **Port language:** Maintainer path — ADDING_A_LANGUAGE + shared CSV contract.
4. **Defend claim:** “We are faster on telemetry stream mode” with suite evidence.

### Docs obligations

- Checklist-first README links.
- Dashboard History + Compare for A/B.
- Explicit: fidelity failures are not speed wins.

---

## Shared anti-patterns (all roles)

- Crowning a **global** multi-language winner from absolute ns.
- Ignoring **data type** and **mode** when quoting ranks.
- Treating **adapted stream** as equal to **native stream** without reading Modes.
- Publishing numbers without **run id** / mode / filter policy.

---

## Attention & copy cheatsheet

| Role | Catch in ≤5 words | Avoid leading with |
|------|-------------------|--------------------|
| student | Learn · try · chart | Filter policy taxonomy |
| integrator | Trade-offs · your language | Full methodology essay |
| researcher | Reproducible · method | Hype badges only |
| author | Add codec · smoke · A/B | Theory course first |

When a page serves **multiple** roles, put the **integrator/student** path first, then link Method/Author deep pages.
