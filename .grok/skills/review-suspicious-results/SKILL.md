---
name: review-suspicious-results
description: >
  Review serializer-benchmark results for suspicious sizes/ops/fidelity, research
  each suspect against the library’s official docs and code examples, fix wrong or
  ineffective harness client call paths (without breaking serializer isolation),
  re-bench, and verify. Use when the user runs /review-suspicious-results, says
  "review suspicious results", "audit benchmark numbers", "check outliers",
  "too fast / too slow serializers", or "verify client calling against package docs".
metadata:
  short-description: "Outlier audit + package-docs-driven client fixes"
---

# /review-suspicious-results — Outlier audit and package-docs-driven fixes

Review published or latest local benchmark numbers for anomalies. For every
**suspect**, you **must** read the library’s official documentation and code
examples before changing harness client code. Do not “fix by intuition” alone.

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
export PATH="$HOME/.local/bin:$PATH"
```

Optional overrides:

| Env / flag | Meaning |
|------------|---------|
| `REVIEW_LANGS` | Space/comma language ids (default: all with stats/logs: `c csharp python rust javascript go`) |
| `REVIEW_FIXTURE` | Suite type focus (default: `message`; also scan all n=1 cells) |
| `REVIEW_MODE` | Bench mode after fixes: `smoke` \| `all-single` \| `full` (default **`all-single`**) |
| `REVIEW_FIX=0` | Report only; do not edit code or re-bench |
| `REVIEW_DOCS_ONLY=0` | If set, skip re-bench after fixes (still require docs research before any edit) |

---

## Non-negotiable rules

1. **Package docs + examples required before any client edit**  
   For each suspect serializer, open and use **at least one** of:
   - Official README / tutorial / “Getting started” on the library’s primary site or GitHub
   - Published API docs (pkg.go.dev, docs.rs, nuget.org readme, pypi project page, npm readme)
   - **Code examples** from that same source (snippets showing serialize/deserialize)
   - Library source for the recommended entry point if docs are thin  

   Record what you read (URL or path + the API you will call).  
   **If you cannot find docs/examples, stop on that suspect and report “blocked: no docs”** — do not invent call paths.

2. **Isolation (C# and anywhere similar)**  
   Serializer wrappers must **not** hard-code suite domain types (`Message`, `Telemetry`, …).  
   Prefer: runtime `Type` / generic binds / injected domain↔native maps.  
   Contracts (FlatBuffer tables, protobuf messages, CSV row DTOs) are OK.

3. **Honest metrics**  
   Prefer real library APIs over envelopes (JSON-in-binary, base64 double-convert, fake stream=bytes).  
   Stream/bytes modes must not be free aliases of each other unless documented as adapted and still different work.

4. **Fidelity**  
   Value-level comparison where the harness provides it; size≈0/1 with “perfect” fidelity is always a red flag.

---

## 1. Scope

```bash
LANGS="${REVIEW_LANGS:-c csharp python rust javascript go}"
# normalize commas → spaces
LANGS="${LANGS//,/ }"
echo "Review languages: $LANGS"
```

Use latest `logs/<lang>/<YYYY-MM-DD-HHMMSS>.csv` and/or `reports/stats_<lang>_latest.json` /
`dashboard/public/data/stats_<lang>_latest.json`.

If the newest CSV is tiny (smoke leftover, &lt;100 rows for a full-matrix language), **prefer the latest full-sized run** or re-run full for that language before concluding.

---

## 2. Scan for suspects (required)

Run the helper (or equivalent analysis):

```bash
python3 .grok/skills/review-suspicious-results/scripts/scan-outliers.py \
  --langs $LANGS \
  --fixture "${REVIEW_FIXTURE:-message}"
```

### Heuristics (flag as suspect)

Within each `(language, test_data, data_type_instance_count, mode)` group:

| Signal | Typical threshold |
|--------|-------------------|
| **TINY size** | size &gt; 0 and size &lt; median/40, or size ≤ 3 for multi-field suite types |
| **HUGE size** | size &gt; median×40 (or envelope smell: size ≈ JSON size of same payload) |
| **HIGH ops** | ops &gt; median×25 (possible no-op, skipped work, wrong N) |
| **LOW ops** | ops &lt; median/40 (possible double work, reflection every call, JSON envelope) |
| **stream ≈ bytes** | median total time within ~5% and code paths identical (fake stream) |
| **errors** | non-empty `logs/<lang>/<stem>.errors.csv` data rows for that serializer |
| **fidelity oddity** | mean_fidelity &lt; 1 with large size, or fidelity 1.0 with tiny size |

Also flag known anti-patterns when reading client code (even if numbers look “ok”):

- JSON/string payload stuffed into another codec “for convenience”
- Base64 encode/decode **inside** the timed stream path
- Reflection / `MakeGenericMethod` **inside** the timed loop (should be untimed prepare)
- Allocating a new encoder/builder every call when the library documents reuse
- Deserializing to the wrong type or always empty/default objects

Write a short **Suspect table**: language | serializer | signal | path to client code.

---

## 3. Research each suspect (package docs + examples) — required

For **each** row in the Suspect table, do **all** of the following before editing:

### 3.1 Locate official sources

| Ecosystem | Prefer |
|-----------|--------|
| C# / NuGet | GitHub README of the package; nuget.org project page; linked docs |
| Python | PyPI project description + GitHub README / docs site |
| Rust | docs.rs + crate README |
| Go | pkg.go.dev + module README |
| JavaScript | npm package README + GitHub |
| C | upstream project README / man pages / header docs |

Use tools: `web_search`, `open_page` / browse, local `node_modules` / crate docs, vendored `third_party` READMEs.

### 3.2 Extract the recommended client pattern

From docs **and** code examples, note:

- Canonical type / builder / encoder construction
- Whether instances should be **reused**
- Serialize / deserialize entry points (`Serialize<T>`, `dumps`/`loads`, `Marshal`/`Unmarshal`, …)
- Stream vs bytes APIs
- Registration / attributes / codegen requirements
- Known limitations (e.g. top-level BSON must be a document)

### 3.3 Diff against harness client

Open the monorepo wrapper (examples):

| Lang | Typical paths |
|------|----------------|
| csharp | `c-sharp/src/Serializers/*`, maps under `c-sharp/src/TestData/V2/Maps/` |
| python | `python/src/benchmark/serializers/*` |
| rust | `rust/src/serializers/*` |
| go | `go/serializers/*` |
| javascript | `javascript/src/serializers/*` |
| c | `c/src/serializers/*`, `c/src/run_v2.c`, `c/src/batch_cell.c` |

Compare:

| Question | If yes → fix |
|----------|----------------|
| Different API than docs recommend? | Align to docs |
| Extra conversions on timed path? | Move to prepare / map |
| Missing prepare/reuse? | Add untimed prepare |
| Fake fidelity (shape-only compare)? | Strengthen compare if harness-owned |
| Isolation broken (suite types in wrapper)? | Use Type bind / maps |

**Document in the final report:** for each fix, `Docs: <url>` + `Example pattern: <snippet summary>` + `Harness was: <…>` + `Harness now: <…>`.

---

## 4. Implement fixes

Only after step 3 for that serializer:

- Edit the wrapper (and domain map only if conversion belongs outside the wrapper).
- Prefer minimal, library-idiomatic changes.
- Do not expand scope to unrelated serializers.
- Keep suite isolation rules (see Non-negotiable #2).

If `REVIEW_FIX=0`, skip to step 7 (report only).

---

## 5. Double-check (re-bench + re-scan)

```bash
MODE="${REVIEW_MODE:-all-single}"
FIXED_LANGS="..."   # languages you edited

for lang in $FIXED_LANGS; do
  ./scripts/run-all-benchmarks.sh -m "$MODE" -l "$lang" --analyze
done

python3 .grok/skills/review-suspicious-results/scripts/scan-outliers.py \
  --langs $FIXED_LANGS \
  --fixture "${REVIEW_FIXTURE:-message}"

# Optional dashboard refresh if you will publish numbers
python3 dashboard/scripts/sync-data.py
```

Confirm:

- Suspect signal is gone or explained as **expected** (with docs cite).
- No new error-CSV regressions for that language.
- Stream vs bytes still differ when stream is claimed.

---

## 6. Expected vs remaining

For each original suspect, classify:

| Status | Meaning |
|--------|---------|
| **fixed** | Client now matches docs; numbers re-checked |
| **expected** | Docs confirm behavior (e.g. pure-JS `cbor` slow; `dill` heavy) |
| **blocked** | No docs/examples found, or library bug with documented workaround only |
| **open** | Still suspicious after fix attempt |

Do **not** mark **fixed** without re-scan (or explicit `REVIEW_FIX=0` report-only mode).

---

## 7. Report format (user-facing)

```markdown
## Suspects found
| Lang | Serializer | Signal | Client path |

## Research & actions
### <serializer> (<lang>)
- Docs: <url>
- Recommended API: …
- Harness issue: …
- Change: …
- Re-check: size/ops before → after (or “expected”)

## Languages clean
- …

## Follow-ups
- …
```

---

## Helper scripts

| Script | Purpose |
|--------|---------|
| `scripts/scan-outliers.py` | Print size/ops outliers per language from latest stats + CSVs |

```bash
python3 .grok/skills/review-suspicious-results/scripts/scan-outliers.py --help
```

---

## Stop conditions

| Condition | Action |
|-----------|--------|
| No stats/logs for a requested language | Warn; skip that lang |
| Suspect found but no package docs/examples | Mark **blocked**; do not invent API |
| Fix breaks isolation (suite types in wrappers) | Revert approach; use maps/Type bind |
| Re-bench fails hard | Stop; report failure |
| `REVIEW_FIX=0` | Research + report only |

---

## Quick checklist (print while working)

- [ ] Scanned all requested langs  
- [ ] For **each** suspect: opened official docs + code example  
- [ ] Compared example to harness client line-by-line  
- [ ] Fixed only with documented APIs  
- [ ] Re-benched affected langs  
- [ ] Re-scanned outliers  
- [ ] Wrote research URLs into the report  
