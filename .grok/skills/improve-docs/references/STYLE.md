# Style guide — docs improvements (README + Dashboard)

Keep it simple. Prefer delete and clarify over decorate.

---

## Scope of “docs” in this skill

| In scope | Out of scope (unless user expands) |
|----------|-------------------------------------|
| Root `README.md` | Full theory 101–401 rewrite |
| `docs/index.md` storefront (if it drifts from README) | Language runner internals |
| `dashboard/` UI copy, layout, light refactors | New chart libraries, redesign from scratch |
| Short Method/Learn *links* and honesty lines | Re-running full multi-lang benches for prose |

---

## Content style

- **One idea per paragraph.** Prefer tables for role/path matrices **on the site / Dashboard**, not by fattening the root README.
- **User terms:** data type, mode (bytes/stream), ops/s, latency, median size, Pareto, baseline.
- **Avoid in user copy:** fixture (internal OK), harness (prefer benchmark runner), unexplained IQR/P95.
- **Honesty line** when ranks appear: within one language; cross-lang directional — prefer **one** place (e.g. Statistics / Method), not a second essay block on README.
- **Links:** prefer site paths that match MkDocs nav labels (Dashboard, Learn, Method). Avoid “storefront” / “CTA” wording in user-facing labels.
- **No emoji spam** in product UI; README badges OK.

### Voice

- Direct, calm, technical. Not marketing hype (“blazing”, “crush”).
- “We measure …” not “We revolutionize …”.
- **No slogan stacks** under the title (“Same A. Same B. Same C.”).
- **No lede hedges** that argue with imaginary critics (“not marketing microbenchmarks”).

### README-specific (authoritative)

See **[README_EDITING.md](README_EDITING.md)** — maintainer rejections and preferred section order from live edit prompts. Summary:

| Prefer | Avoid |
|--------|--------|
| Short factual lede | Expanded role “know/want/tasks” on README |
| Compact Who-it-is-for table | Second “How to read the numbers” section without ask |
| Try it → then Quick start | “Full quick start” naming |
| Surgical user-driven edits | Big-bang README rewrites in a cycle without buy-in |

---

## Visual design (Dashboard)

- Stay on existing Material/Google-ish tokens in `index.css` (`--color-blue`, glass panels).
- New UI: reuse `.glass-panel`, `.section-help`, `.tab-btn`, `.badge-*`.
- Help / orientation: one compact strip; dismissible; not a modal maze.
- Do not introduce second font stacks or heavy animation.
- Mobile: respect existing breakpoints (~720px); don’t break sticky header.

---

## Internal implementation

| Rule | Detail |
|------|--------|
| Prefer small diffs | Touch the fewest files that deliver the ranked items |
| No framework churn | Stay on vanilla JS + Chart.js + Vite as today |
| Refactor only if it shrinks | Extract string constants / help HTML when duplicating; don’t rename half of `main.js` |
| localStorage keys | Version suffix if schema changes (`…-v2`); migrate or ignore old |
| Build | `dashboard` Vite build if assets ship via `docs/dashboard`; keep `index.html` source of truth in `dashboard/` |
| Tests | No dashboard unit suite today — smoke-check in browser or `npm run build` if available |

### Complexity budget

- Cycle implements **≤3** ranked items.
- Avoid net +200 LOC unless removing more elsewhere.
- If `main.js` must grow, put new copy in one `ORIENTATION` / `HELP` constant block at top of the UI section.

---

## Cycle discipline (summary)

1. Read `ROLES.md`, `RESEARCH.md`, `README_EDITING.md`, this file — **do not recreate** if present; only amend.
2. Analysis → Plan → Critique plan → Implement ≤3 → Critique implementation → Fix.
3. Stop when wall time for the whole workflow &lt; 1 hour **or** no high-importance items remain.
4. Update the skill + references from what you learned.
5. `/prepare-pr` (docs-only: empty changed langs is OK).

---

## File layout for this skill

```text
.grok/skills/improve-docs/
  SKILL.md
  references/
    ROLES.md
    RESEARCH.md
    STYLE.md
    README_EDITING.md
    CYCLE_LOG.md
```
