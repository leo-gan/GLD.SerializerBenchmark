# Docs improvement cycle log

Started: 2026-07-30 (workflow budget &lt; 1h). Surfaces: **README** + **Dashboard**.

---

## Cycle 1 — Analysis (Content · Visual · Implementation)

### Content

| Finding | Severity | Roles hit |
|---------|----------|-----------|
| README “Who it is for” is a thin table — no typical tasks, no “knows/doesn’t know”, weak routing | High | all |
| README lacks a short “how to read numbers” honesty block near CTAs (only buried under Statistics) | High | student, integrator |
| Dashboard has no first-visit orientation; jargon (IQR, Pareto, P95) appears cold | High | student, integrator |
| Cross-lang honesty only in Compare when cross is open — overview never reminds within-language | Med | integrator |
| “Test Data” label vs internal “data type” terminology | Med | all |
| docs/index.md already clearer than README on honesty — slight drift | Med | student |

### Visual design

| Finding | Severity |
|---------|----------|
| Dense toolbar: Language / Test Data / Mode / Samples + metric tabs with no “start here” hierarchy | High |
| KPI cards good; charts good; missing compact honesty/orientation strip | High |
| Help text exists on ranking/table but not global; Compare toolbar is very dense | Med |
| Mobile nav exists; orientation must stay one line–two lines | Med |

### Internal implementation

| Finding | Severity |
|---------|----------|
| `main.js` ~3.5k LOC — large; avoid mega-refactor this cycle | — |
| Orientation can be pure HTML/CSS + tiny dismiss handler (~30 LOC) | Low risk |
| No need to touch sync-data / gzip for prose | — |

### Important vs not

- **Important:** role routing, honesty near numbers, first-run orientation, plain labels.
- **Not this cycle:** redesign Compare matrix, extract main.js modules, rewrite theory course, full a11y audit.

---

## Plan (ranked)

1. **[P1 Content]** Expand README “Who it is for” with role use cases + add “How to read the numbers” honesty. Align role links.
2. **[P1 Content+Visual]** Dashboard dismissible orientation strip: what to do first + within-language honesty + gloss (Pareto, data type, mode).
3. **[P2 Content]** Toolbar: rename “Test Data” → “Data type”; short title tooltips on Mode / Samples for non-experts.

Deferred: docs/index.md sync if time; deep Compare simplification; main.js split.

---

## Critique of plan

- P1+P2 are high leverage for students/integrators without refactor risk. Good.
- Risk: orientation strip becomes permanent clutter → must be dismissible + localStorage.
- Risk: README gets long → keep role section as compact table + 4 short bullets max.
- Drop separate docs/index.md edit unless one-liner; storefront already has honesty.
- Implementation cap: 3 items = exactly P1 README, P2 orientation, P3 labels/tooltips.

---

## Implementation notes

| Item | Files |
|------|--------|
| P1 README roles + “How to read the numbers” | `README.md` |
| P1b storefront honesty align | `docs/index.md` (light) |
| P2 orientation banner | `dashboard/index.html`, `index.css`, `main.js` (`ORIENTATION_KEY`) |
| P3 Data type labels + tooltips | `dashboard/index.html` |
| Publish | `npm run build` → `docs/dashboard/` |

---

## Critique of implementation

| Check | Result |
|-------|--------|
| Student sees start path on README | Yes — role table + honesty |
| Integrator: data type + mode called out | Yes — README + tooltips + banner |
| Banner not permanent clutter | Dismiss → localStorage `…-v1` |
| Progressive enhancement | Banner visible by default; JS only hides if dismissed |
| main.js growth | ~35 LOC helper; acceptable |
| Anchor to smoke section | GitHub slug may strip `~`; monitor |
| Residual backlog | Compare toolbar density; main.js split; Learn page cross-links; optional “show tip again” |

**Stop:** cycle goals met; workflow under 1h; go to skill update + prepare-pr.
