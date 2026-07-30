# Research notes — standards for role-oriented docs

Working notes for improving **README** + **Dashboard** (and related docs).  
**Common sense beats everything** — drop a “best practice” if it adds complexity without helping a role.

Sources mixed: Google Technical Writing, open technical communication audience analysis, dashboard UX literature (comparison, hierarchy, cognitive landmarks), cognitive load / progressive disclosure. Not a literature review; a decision aid.

---

## 1. Audience-centered writing

| Principle | Practice here |
|-----------|----------------|
| Docs = (knowledge needed) − (knowledge already held) | Students need definitions; researchers need procedure ids |
| Expert / technician / executive / non-specialist | Map: researcher≈expert, author≈technician, integrator≈executive+technician, student≈non-specialist→technician |
| Personas as composites | Use `ROLES.md`; do not invent fifth personas for every page |
| Task first | Every major surface answers a primary question (see architecture reader table) |

### Plain language

- Prefer **data type** (user-facing) over fixture jargon.
- Spell out first use: “Pareto frontier (best speed/size trade-offs)”.
- Stats labels (P95, IQR, CV) need a one-line gloss or Method link nearby.
- Active voice, short paragraphs, tables for parallel facts.

### Honesty / scientific communication

- State **limits of inference** near the numbers (within-language; host/runtime differ).
- Prefer **median + spread** framing over single “ops” hero metrics when teaching.
- Disclose cleaning (warmup drop, filter policy) where rankings are shown.
- Cross-language: **directional only** — always visible when that path is active; soft reminder on overview is OK.

---

## 2. Dashboard / visualization standards

| Principle | Practice here |
|-----------|----------------|
| Visual hierarchy | KPIs → trade-off chart → ranking → dense tables |
| Right chart | Scatter for trade-off; bars for ranking; table for exact values |
| Comparison + baselines | Relative cells (`ratio×`) and baseline pickers already match “cognitive landmarks” |
| Progressive disclosure | Advanced: filter policy, custom metrics, cross-lang — collapse or second row |
| Don’t overcrowd | Prefer one help strip over five competing banners |
| Zero baseline on bar magnitude | Keep ranking scales honest |
| Accessibility | Labels on controls, contrast, `aria-*`, keyboard-friendly selects |
| Empty / loading states | Explicit “Loading…” / no-data copy beats blank charts |

### Cognitive load

- Working memory is small: default path should need **language + data type** only.
- Power features stay available without being the first wall of chrome.
- Dismissible orientation OK; do not nag after dismiss (localStorage).

---

## 3. README / storefront standards

| Principle | Practice here |
|-----------|----------------|
| 30-second scan | Badges + one-liner + Start here table |
| Role routing | Who-it-is-for → use case → deep link |
| Try path | 60s smoke for one language before full install |
| Consistent CTAs | Dashboard / Learn / Method names match site tabs |
| No orphan claims | Counts and “fair” claims link to evidence or method |

---

## 4. Implementation (code) standards for docs surfaces

| Principle | Practice here |
|-----------|----------------|
| Simplicity | Prefer small HTML/CSS/JS changes over new frameworks |
| Structure | Keep modules (`format.js`, `charts.js`, `main.js`); avoid mega-refactors mid-cycle |
| Terminology | Single user-facing term list; comments may lag |
| Size | Reduce duplication (labels, help strings) when touching a file |
| No drive-by | Do not re-bench or churn `*_latest.json.gz` for copy-only edits |

---

## 5. What we deliberately skip

- Full WCAG audit every cycle (fix critical a11y when editing UI).
- Academic readability formulas (Flesch) as gates — use human review against roles.
- Dark-pattern “engagement” gamification on benchmarks.

---

## 6. Quick evaluation checklist (per change)

1. Which **role** is primary? Secondary?
2. Can a **student** understand the first screen without Method?
3. Can an **integrator** reach a within-language trade-off in &lt;3 clicks?
4. Can a **researcher** find run id, mode, filter policy?
5. Can an **author** find smoke + add-serializer path from README?
6. Did we add jargon without a gloss?
7. Did code get **simpler** or only larger?
