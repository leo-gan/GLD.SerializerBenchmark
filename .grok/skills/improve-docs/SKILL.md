---
name: improve-docs
description: >
  Improve serializer-benchmark documentation (README + Dashboard primarily) in
  timed cycles: load Roles/Research/Style, analyze content/visual/implementation,
  plan and critique, implement ≤3 high-importance items, critique fixes, update
  this skill and references, then prepare-pr. Use when the user runs /improve-docs,
  says "improve docs", "docs improvement cycle", "dashboard docs UX", or asks to
  refine README/dashboard for students, integrators, researchers, or authors.
metadata:
  short-description: "Cycled README + Dashboard docs improvements"
---

# /improve-docs — Role-driven docs improvement cycles

Repo-local skill. Resolve monorepo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

**Finish condition:** whole workflow wall time **&lt; 1 hour**. Prefer one solid cycle over many shallow ones.

**Surfaces (default):** root `README.md` + `dashboard/` (built into `docs/dashboard/`).  

When the user asks for **deep** validation, expand to: storefront `docs/index.md`, **all** language overviews, theory level indices (101–401), Benchmarks section indices, plus dashboard visuals—still **without** fattening README against `README_EDITING.md`.

---

## 0. Load foundation (do not recreate)

| File | Purpose |
|------|---------|
| [references/ROLES.md](references/ROLES.md) | Four roles, profiles, use cases, attention cheatsheet |
| [references/RESEARCH.md](references/RESEARCH.md) | Writing + dashboard standards (common sense wins) |
| [references/STYLE.md](references/STYLE.md) | Content/visual/code constraints and complexity budget |
| [references/README_EDITING.md](references/README_EDITING.md) | **Maintainer README preferences** from live prompts (overrides fat README rewrites) |
| [references/CYCLE_LOG.md](references/CYCLE_LOG.md) | Optional last-cycle analysis/plan notes |

If a file is **missing**, create it from the templates’ intent (roles = student, integrator, researcher, author). If it **exists**, amend only when the cycle teaches something new.

### Critical lesson (README)

A full cycle once **expanded** README (role know/want table, typical tasks, “How to read the numbers”). The maintainer **rolled that package back**, then applied **surgical** cuts and section moves.  

**Do not re-apply the expanded README pattern.** Put persona depth in `ROLES.md` and site/Dashboard copy. Treat `README_EDITING.md` as binding for root `README.md`.

---

## 1. Roles (quick check)

Confirm the four primary roles still match product copy:

1. **Student** — Learn 101–201, plain language, first chart
2. **System integrator** — within-language trade-offs, Pareto, Compare
3. **Researcher** — methodology, filter policies, run ids, replication
4. **Serializer author** — add codec, smoke, A/B

Use cases and “knows / doesn’t know” live in `ROLES.md`. Do not invent a fifth landing persona without evidence in README/architecture.

---

## 2. Cycle workflow

Repeat until finish condition or no high-importance items remain.

### 2.1 Analysis (all three dimensions)

| Dimension | Look for |
|-----------|----------|
| **Content** | Missing role paths, honesty near numbers, jargon without gloss, README↔storefront drift, ambiguous Mode/data type |
| **Visual** | Hierarchy, clutter, missing orientation, dense toolbars, mobile breakage |
| **Implementation** | Duplication, oversized `main.js` touch surface, dead copy, build path to `docs/dashboard` |

Record findings in `references/CYCLE_LOG.md` (severity, roles hit). Mark important vs not.

### 2.2 Plan

Propose improvements; **rank by importance**. Cap delivery at **≤3 items** per cycle.

### 2.3 Critique the plan

Cut scope creep, ensure dismissible UI is not permanent noise, prefer small diffs, refuse mega-refactors of `main.js` unless size drops.

### 2.4 Implementation

- Edit sources under `dashboard/` then **`npm run build`** in `dashboard/` so `docs/dashboard/` updates.
- **README:** follow `README_EDITING.md` — short lede, compact audience table, section order Who → languages → Try it → Quick start; no slogan/meta CTA prose; no unsolicited role expansion.
- MkDocs storefront (`docs/index.md`) only if asked or if it clearly contradicts a user-approved README fact.
- Follow `STYLE.md` (simple, no new frameworks, terminology: **data type** not fixture).

### 2.5 Critique the implementation

Re-read as each role. Fix regressions (broken anchors, always-on banners, label inconsistency). Rebuild dashboard if HTML/JS/CSS changed.

### 2.6 Finish check

```bash
# rough elapsed if you recorded start
date
```

If **&lt; 1h** and top issues for this session are done → stop cycling. Else another Analysis pass only if time remains and P1 items exist.

---

## 3. After cycles: skill + references

1. Update `CYCLE_LOG.md` with what shipped and residual backlog.
2. Amend `ROLES.md` / `RESEARCH.md` / `STYLE.md` / `README_EDITING.md` only if the cycle or maintainer prompts invalidated something.
3. Improve **this** `SKILL.md` if the procedure was wrong or incomplete.

---

## 4. Prepare PR

Run the **prepare-pr** skill (`.grok/skills/prepare-pr/SKILL.md`).

Docs-only / skill-only / dashboard UI: expect **empty changed languages** → skip full benches; still run tests, optional `sync-data.py` (avoid gzip-only churn), commit, push, draft PR.

```bash
# Typical docs-only validation extras
( cd analysis && uv run pytest -q )
( cd dashboard && npm run build )
```

Do **not** force `PREPARE_PR_BENCH_ALL` for copy/UI-only work.

---

## Agent checklist

1. [ ] Foundation loaded (not recreated blindly)
2. [ ] Analysis across Content / Visual / Implementation
3. [ ] Plan ranked; ≤3 implemented
4. [ ] Plan + implementation critiqued; fixes applied
5. [ ] `dashboard` built into `docs/dashboard` when UI changed
6. [ ] Skill + references updated
7. [ ] prepare-pr (or explicit commit/PR if user forbids full gate)

---

## File layout

```text
.grok/skills/improve-docs/
  SKILL.md
  references/
    ROLES.md
    RESEARCH.md
    STYLE.md
    README_EDITING.md   # maintainer README prefs (from prompt analysis)
    CYCLE_LOG.md
```

---

## Related

- **prepare-pr** — test / optional bench / analyze / sync-data / push / PR
- **clean-logs** — prune logs; unrelated to prose unless disk blocks work
- Site tabs: Learn · Languages · Benchmarks · Dashboard · Experiments
