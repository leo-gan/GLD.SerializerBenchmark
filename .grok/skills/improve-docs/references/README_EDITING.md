# README editing — maintainer preferences (learned)

Evidence: post-cycle README prompts on branch `docs-improvements` (after the first improve-docs pass).  
**These rules override generic “expand for personas” instincts for root `README.md`.**

---

## What happened (session trace)

| User prompt (paraphrase) | Signal |
|--------------------------|--------|
| Home cell: not “Project storefront (CTAs…)”; just Home + URL | Hate **meta / marketing labels** and parenthetical CTA tutorials in the Start table |
| Then: remove whole Start here table | Willing to **delete structure** that feels noisy (later full rollback restored it) |
| **Rollback README** — “I don’t like your changes” | The cycle’s **role-expanded** Who-it-is-for + Typical tasks + “How to read the numbers” was **rejected as a package** |
| commit | Prefer commit after rollback; keep other surfaces (dashboard skill) if still wanted |
| Drop slogan: “Same data types. Same CSV contract…” | No **triadic slogan** under the title |
| Drop: “— with fair within-language rankings, not marketing microbenchmarks” | Lede stays a **single plain fact**; no self-defensive “not marketing” clause |
| Who it is for **before** Try it | Audience orientation early |
| Try it **before** Full quick start; rename → **Quick start** | Concrete 60s path immediately before broader install; naming without redundant “Full” |

Net preferred **section order** (after those edits):

1. Title + badges  
2. One-line lede (facts only)  
3. Start here table (still present after rollback; only edit if user asks)  
4. Example plot  
5. **Who it is for** (compact original table: Audience / Use case / Course)  
6. **Supported languages**  
7. **Try it** (Python ~60s smoke)  
8. **Quick start** (full host path; not “Full quick start”)  
9. Test data · Statistics  

---

## Hard rules for README (do not “improve” past these)

### Do

- Prefer **delete and shorten** over adding sections, slogans, or second honesty blocks.
- Keep **Who it is for** as a **small table** (audience · use case · course links). Roles deep-dives belong in `ROLES.md` / site, not a longer README.
- Keep **Try it** as the shortest runnable path; **Quick start** for the broader path.
- One short lede sentence. Badges already carry Home / Dashboard / Learn.
- Apply **user-sized diffs** when the user gives imperative README edits (“remove X”, “move Y before Z”).

### Do not

- Re-expand README with: long role profiles, “you already know / you want”, typical-task bullet lists, or a second **How to read the numbers** section (unless the user **explicitly** asks again).
- Add slogan stacks (“Same A. Same B. Same C.”).
- Add lede hedges like “not marketing microbenchmarks”, “fair within-language rankings” as taglines (honesty can stay once under **Statistics**).
- Call the site “storefront” or explain “CTAs” in the Start table.
- Rename **Quick start** back to **Full quick start**.
- Big-bang rewrite of README in a docs cycle without showing a **short plan** and getting buy-in — this maintainer **rolls back** disliked packages.

### Voice

- Plain, denser info tables OK.  
- No product-marketing gloss.  
- Link labels: **Home**, **Dashboard**, **Learn**, **Method** — not “project storefront”.

---

## How agents should work on README

1. **Surgical default:** one requested change at a time; match wording literally.
2. **If proposing structure changes:** list ≤3 bullets first; wait if the change is large (new sections, role rewrite).
3. **After user rollback:** treat that file’s prior agent expansion as **forbidden** until they re-request it.
4. **Roles research still useful** for Dashboard / Learn / Method — not as an excuse to fatten README.
5. When storing new preferences: append to **this file** with date + short prompt paraphrase.

---

## Link to dimensions

| Dimension | README implication |
|-----------|-------------------|
| Content | Less prose; original audience table; no dual honesty blocks |
| Visual (GitHub render) | Order: audience → languages → try → quick start; short lede above fold |
| Implementation | n/a for pure Markdown; no drive-by docs/index sync unless asked |

---

## Residual (not decided by those prompts)

- Whether **Start here** table stays long-term (removed once, restored by full rollback).
- Whether Home cell should be bare URL only (requested once, then full rollback undid it).
- Storefront (`docs/index.md`) alignment with the shorter lede — only if user asks.
