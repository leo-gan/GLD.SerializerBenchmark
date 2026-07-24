---
name: review-suspicious-results
description: >
  Review serializer-benchmark results for suspicious sizes/ops/fidelity, research
  each suspect against the library’s official docs and code examples, fix wrong or
  ineffective harness client call paths (without breaking serializer isolation),
  re-bench, and verify. Also covers “official package is optimal but still too
  slow” cases: research ecosystem high-perf peers (e.g. serde_avro_fast vs
  apache-avro) when a binary/schema codec lags same-lang JSON. Use when the user
  runs /review-suspicious-results, says "review suspicious results", "audit
  benchmark numbers", "check outliers", "too fast / too slow serializers", or
  "verify client calling against package docs".
metadata:
  short-description: "Outlier audit + package-docs-driven client fixes"
---

# /review-suspicious-results — Outlier audit and package-docs-driven fixes

Review published or latest local benchmark numbers for anomalies. For every
**suspect**, you **must** read the library’s official documentation and code
examples before changing harness client code. Do not “fix by intuition” alone.

**Also mandatory:** batch-axis (`n=1` vs `n=N`) and cross-language size checks, plus
reading the **run harness** (cell construction / batch framing), not only serializer
wrappers. Within-group relative scans alone are **not sufficient** (see
[Lessons learned](#lessons-learned-why-rust-speedy-n100-was-missed)).

**Also mandatory for “too slow” schema/binary codecs:** if the client already
matches the **official** crate’s best public API but still loses to **same-language
JSON**, do **not** stop at “expected, docs only have this API.” Research whether
the ecosystem’s **throughput-oriented** library is a different package (see
[Lessons learned: official Avro lagging JSON](#lessons-learned-official-apache-avro-lagged-json-on-rust)).

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
export PATH="$HOME/.local/bin:$PATH"
```

Optional overrides:

| Env / flag | Meaning |
|------------|---------|
| `REVIEW_LANGS` | Space/comma language ids (default: all with stats/logs: `c csharp python rust javascript go java cpp`) |
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

5. **Label must equal work (LABEL≠WORK)**  
   If CSV / stats say `DataTypeInstanceCount=N` (or fixture `@n=N`), the timed path must
   **encode and decode N real instances** (or a documented batch frame of N payloads).
   Size and wall time must scale with N. A harness that labels N but serializes one
   object is a **critical** bug — treat as higher priority than a single slow library.

6. **Harness runners are in scope, not only wrappers**  
   Suspects may live in `run_v2` / `batch_cell` / cell builders, not in `serializers/*`.
   Package docs proving the wrapper API is correct **do not** close the case if the
   runner under-feeds the wrapper.

7. **Official ≠ automatically the suite choice for throughput**  
   Matching the official package’s documented hot path is necessary but not always
   sufficient. If a **schema/binary** codec is slower than same-lang **JSON** on
   small fixtures (e.g. `message@n=1`) with correct size and fidelity, treat that
   as a **hard suspect**: either the client is wrong, or the **wrong library** was
   selected for a performance suite. Research high-perf reimplementations that
   stay wire-compatible (or document dual rows like Go’s hamba/avro + goavro).

8. **Split ser vs deser when diagnosing “too slow”**  
   Log mean `TimeSer` and `TimeDeser` separately. A healthy binary ser with a
   multi-× deser often means intermediate graphs (`Value`, maps), not buffer
   setup. That pattern points at **library design / choice**, not only reuse.

---

## Lessons learned: why Rust speedy `@n=100` was missed

### What the user saw

Dashboard: Rust **speedy** (and peers) at `message@n=100` looked ~100× too fast / too
small vs other languages for the same fixture and N. Speedy’s crate docs and the
Rust wrapper API looked fine.

### What was actually wrong

Harness bug in `rust/src/run_v2.rs` (batch cell construction), **not** Speedy:

- Config labeled `data_type_instance_count = 100`.
- Cell only built **one** fixture (`make_one` once) and serialized that single value.
- CSV still wrote `DataTypeInstanceCount=100`.
- **Every** Rust serializer shared the same under-encode path → relative ranking inside
  Rust looked “normal” (speedy still fastest among peers).
- Package-docs review of `rust/src/serializers/speedy*` correctly concluded “API matches
  docs” and closed the case.

### Why the skill / scan failed

| Blind spot | Effect |
|------------|--------|
| **Within-group outliers only** | Groups are `(lang, fixture, n, mode)`. All codecs wrong the same way → no TINY/HIGH flags. |
| **No n=1 vs n=N axis** | Never asked `size(n=100)/size(n=1) ≈ 100?` or `ops(n=100) ≪ ops(n=1)?`. |
| **No cross-language size peers** | Never asked “is Rust median `message@n=100` size ≪ C#/Python/JS/Go for same N?”. |
| **Docs-only on wrappers** | Speedy README validates the crate call; it cannot detect runner LABEL≠WORK. |
| **“Looks intentional” code** | Comments / early paths that only use the first instance feel deliberate; still must match the **label** and W×C contract. |
| **Ops/size thresholds too loose for shared bugs** | Thresholds catch one weird codec, not a whole language under-encoding. |

### Rules derived (must follow every review)

1. Run `scan-outliers.py` and **read** sections: within-group, **BATCH-AXIS / LABEL≠WORK**, **CROSS-LANGUAGE**.
2. For every language that has both `n=1` and `n>1` rows: require roughly  
   `size(n=N) / size(n=1) ≳ N/10` (flag if ≪, e.g. ratio ~1 for N=100).  
   Also flag if `ops(n=N) / ops(n=1) ≳ 0.8` when N is large (work did not scale).
3. Cross-lang: if one language’s median size for `fixture@n=N` is **≪ peer median / 5**, treat the **entire language harness** as suspect (runner/batch), not one serializer.
4. Always open **runner + batch cell** code paths (table below), not only `serializers/*`.
5. Dashboard “too fast at high n” screenshots are first-class evidence — do not dismiss because within-lang scan is clean.
6. Never mark a language **clean** solely because within-group SUSPECTS is empty.

### Case study fix (reference)

- Build `Vec` of N fixtures via `make_one(..., instance_index=i, ...)`.
- Timed path: length-prefixed batch frame (u32 count + per-item u32 len + payload), same idea as C `batch_cell`.
- Deserialize N items; fidelity over the full batch.
- Re-bench; confirm `size(n=100)/size(n=1) ≈ 100` and cross-lang peer sizes align in order of magnitude.

---

## Lessons learned: official `apache-avro` lagged JSON on Rust

### What the user saw

Rust **Avro** on `message@n=1` was slower than **`serde_json` / `sonic-rs`**, while
C# Avro sat near protobuf peers after a hot-path fix. Size (~47 B) matched
Java/Go Avro and scaled with N — so LABEL≠WORK was clean. “Avro slower than JSON”
looked like nonsense for a binary schema format.

### What was actually wrong

**Not** a broken harness client for the official crate:

| Check | Result |
|-------|--------|
| Size / fidelity / batch axis | OK |
| Ser path `write_avro_datum_ref` | Already the crate’s recommended fast write |
| Deser path `from_avro_datum` + `from_value` | **Only** public single-datum API |

Measured split (`message@n=1` bytes, ~mean ns):

| Codec | ser | deser | total |
|-------|-----|-------|-------|
| prost | ~80 | ~100 | ~180 |
| sonic-rs | ~130 | ~230 | ~360 |
| serde_json | ~140 | ~310 | ~450 |
| **apache-avro** | **~200** | **~700** | **~900** |

Serialize was competitive; **deserialize** built a heap intermediate `Value` graph
then converted to the struct. Matching “official docs” correctly still produced
nonsense rankings vs JSON.

### Why the first review almost closed as “expected”

| Blind spot | Effect |
|------------|--------|
| **Docs match = done** | Confirmed optimal *for apache-avro*, stopped researching *other Avro crates* |
| **“Expected library cost” too early** | Treated two-step `Value` API as inevitable without checking ecosystem peers |
| **No mandatory schema-vs-JSON check** | Scanner LOW-ops thresholds (median/40) do not fire when Avro is only 2× slower than JSON peers in a group full of binary codecs |
| **Ser/deser not split** | Total time looked “a bit slow”; deser multi-× ser was the smoking gun |
| **Official brand preference** | Assumed Apache SDK is the right suite row (Python uses **fastavro**, Go often **hamba/avro**, not only the oldest port) |

### Fix (reference)

- Research: [serde_avro_fast](https://github.com/Ten0/serde_avro_fast) — one-pass serde, no `Value`; claims ~10–20× vs apache-avro; local microbench ~4× total on suite `Message`.
- **Wire check:** same datum bytes as `apache-avro` for suite schemas; cross-deser both ways.
- Harness: switch (or add) row to `serde_avro_fast` with reused `SerializerConfig` + `to_datum` / `from_datum_slice` ([docs](https://docs.rs/serde_avro_fast)).
- After: `message@n=1` ~**270 ns** total — **faster than serde_json/sonic-rs**, near prost.

### Rules derived (must follow every “too slow” review)

1. **Schema/binary slower than same-lang JSON on small fixtures is never “fine” by default.** Flag it even when within-group LOW-ops does not fire.
2. After confirming the client matches the **current package’s** best API, still ask:  
   **Is there a widely used high-throughput alternative in this language?**  
   Examples: Python `fastavro` vs pure Avro; Go `hamba/avro` vs `linkedin/goavro`; Rust `serde_avro_fast` vs `apache-avro`; C# Reflect vs Specific (codegen) when Reflect still lags peers after reuse.
3. Before marking **expected**:  
   - Split ser vs deser.  
   - Microbench official vs candidate peer (same payload).  
   - Verify **wire compatibility** (or document dual rows if formats differ).  
   - Prefer the suite default that reflects **realistic high-perf usage** (like other langs), not only brand/official.
4. Do **not** mark **expected** solely because “docs only expose API X” if another crate is the ecosystem’s throughput path for the **same format**.
5. Optional dual registration (official + fast) is fine when both are honest suite rows (Go already does this for Avro).

---

## 1. Scope

```bash
LANGS="${REVIEW_LANGS:-c csharp python rust javascript go java cpp}"
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

The script prints **three** classes of findings. **All three are mandatory to act on:**

| Section | What it catches |
|---------|-----------------|
| `SUSPECTS within-group` | One codec tiny/huge/fast/slow vs peers **at the same n** |
| `BATCH-AXIS / LABEL≠WORK` | `n=N` size or ops not scaling vs `n=1` for same serializer |
| `CROSS-LANGUAGE` | Whole language median size outlier vs other langs at same fixture@n |

### Heuristics (flag as suspect)

#### A. Within each `(language, test_data, data_type_instance_count, mode)` group

| Signal | Typical threshold |
|--------|-------------------|
| **TINY size** | size &gt; 0 and size &lt; median/40, or size ≤ 3 for multi-field suite types |
| **HUGE size** | size &gt; median×40 (or envelope smell: size ≈ JSON size of same payload) |
| **HIGH ops** | ops &gt; median×25 (possible no-op, skipped work, wrong N) |
| **LOW ops** | ops &lt; median/40 (possible double work, reflection every call, JSON envelope) |
| **slower than same-lang JSON** | **schema/binary** codec total time **&gt; same-lang JSON peer** (e.g. `serde_json` / `System.Text.Json`) on `message@n=1` with sane size — always flag; do not rely on median/40 alone |
| **deser ≫ ser** | mean deser time **&gt; ~3×** mean ser for binary codecs (intermediate `Value`/map graph smell) |
| **stream ≈ bytes** | median total time within ~5% and code paths identical (fake stream) |
| **errors** | non-empty `logs/<lang>/<stem>.errors.csv` data rows for that serializer |
| **fidelity oddity** | mean_fidelity &lt; 1 with large size, or fidelity 1.0 with tiny size |

#### B. Batch axis (same language, same serializer, `n=1` vs `n=N`) — **required**

| Signal | Typical threshold | Meaning |
|--------|-------------------|---------|
| **size ratio too small** | `size(N)/size(1) < max(1.5, N/10)` e.g. N=100 and ratio &lt; 10 | Not encoding N instances |
| **ops do not drop** | `ops(N)/ops(1) > 0.8` for large N | Same work as n=1 despite label N |

These fire even when **every** serializer in the language is equally wrong.

#### C. Cross-language size peers — **required**

| Signal | Typical threshold | Meaning |
|--------|-------------------|---------|
| **lang median ≪ peers** | median size(lang) &lt; peer_median / 5 at same fixture@n | Whole-language under-encode / wrong N |
| **lang median ≫ peers** | median size(lang) &gt; peer_median × 5 | Envelope or over-count |

#### D. Code anti-patterns (even if numbers look “ok”)

- JSON/string payload stuffed into another codec “for convenience”
- Base64 encode/decode **inside** the timed stream path
- Reflection / `MakeGenericMethod` **inside** the timed loop (should be untimed prepare)
- Allocating a new encoder/builder every call when the library documents reuse
- Deserializing to the wrong type or always empty/default objects
- **Building only one fixture when `instance_count > 1`**
- **Writing `DataTypeInstanceCount=N` while serializing a single value**
- Batch framing that drops lengths / counts so deser always sees one item

Write a short **Suspect table**: language | serializer **or harness** | signal | path to client **or runner** code.

---

## 3. Research each suspect (package docs + examples) — required

For **each** row in the Suspect table, do **all** of the following before editing.

### 3.0 Classify: wrapper vs harness

| Signal origin | Research focus |
|---------------|----------------|
| Within-group single serializer | Package docs + that wrapper |
| BATCH-AXIS many serializers same lang | **Runner / batch cell first**; docs second |
| CROSS-LANGUAGE whole lang tiny | **Runner / batch cell first** |
| User dashboard “all X look too fast at n=100” | **Runner / batch cell first** |

If harness is wrong, fix harness; do not churn serializer wrappers or mark “expected” from crate docs alone.

### 3.1 Locate official sources (wrappers)

| Ecosystem | Prefer |
|-----------|--------|
| C# / NuGet | GitHub README of the package; nuget.org project page; linked docs |
| Python | PyPI project description + GitHub README / docs site |
| Rust | docs.rs + crate README |
| Go | pkg.go.dev + module README |
| JavaScript | npm package README + GitHub |
| C | upstream project README / man pages / header docs |

Use tools: `web_search`, `open_page` / browse, local `node_modules` / crate docs, vendored `third_party` READMEs.

See also [references/package-docs-lookup.md](references/package-docs-lookup.md).

### 3.2 Extract the recommended client pattern

From docs **and** code examples, note:

- Canonical type / builder / encoder construction
- Whether instances should be **reused**
- Serialize / deserialize entry points (`Serialize<T>`, `dumps`/`loads`, `Marshal`/`Unmarshal`, …)
- Stream vs bytes APIs
- Registration / attributes / codegen requirements
- Known limitations (e.g. top-level BSON must be a document)
- Whether ser/de is **one-pass** into the domain type or builds an intermediate (`Value`, `GenericRecord`, map) every call

### 3.2b Ecosystem peer research (required when “too slow” after API match)

If the wrapper already matches the package’s best public API **and** the codec is still
suspicious vs same-lang peers (especially **slower than JSON**):

1. Search for high-performance reimplementations of the **same format** in that language  
   (`fastavro`, `serde_avro_fast`, `hamba/avro`, codegen/Specific paths, …).
2. Open **that** package’s README + examples; microbench against the official crate on one suite type.
3. Check **wire compatibility** (identical or documented framing differences).
4. Decide: **switch** the suite row, **add a second row** (official + fast), or document why the slow official path must stay alone.
5. Only then mark residual slowness as **expected**.

Do not invent APIs. Do not stay on a known multi-×-slower stack solely for “official” branding when the suite already prefers throughput libraries elsewhere (Python Avro = fastavro).

### 3.3 Diff against harness client **and** runner

Open the monorepo wrapper **and** the batch/runner paths:

| Lang | Serializer wrappers | Runner / batch (LABEL≠WORK lives here) |
|------|---------------------|----------------------------------------|
| csharp | `c-sharp/src/Serializers/*` | `c-sharp/src/*` run loop, config resolve, `DataTypeInstanceCount` usage |
| python | `python/src/benchmark/serializers/*` | suite runner / instance list construction |
| rust | `rust/src/serializers/*` | **`rust/src/run_v2.rs`**, `rust/src/data_v2.rs` (`make_one`) |
| go | `go/serializers/*` | go runner / fixture batch build |
| javascript | `javascript/src/serializers/*` | JS runner / fixture array for N |
| java | `java/src/main/java/benchmark/serializers/*` | Main / Cells / instance count |
| cpp | `cpp/src/serializers/*` | `register.cpp` / runner cells |
| c | `c/src/serializers/*` | **`c/src/run_v2.c`**, **`c/src/batch_cell.c`** |

Compare:

| Question | If yes → fix |
|----------|----------------|
| Different API than docs recommend? | Align to docs |
| Extra conversions on timed path? | Move to prepare / map |
| Missing prepare/reuse? | Add untimed prepare |
| Fake fidelity (shape-only compare)? | Strengthen compare if harness-owned |
| Isolation broken (suite types in wrapper)? | Use Type bind / maps |
| **Label N but only one fixture built?** | Build N fixtures; batch frame ser/deser |
| **Fidelity checks only first item of batch?** | Check all N (or documented sample with honest size) |
| **Client matches docs but still ≪ JSON / peers?** | Run §3.2b ecosystem peer research; switch or dual-register if wire-compatible |
| **Deser multi-× ser with intermediate Value/map?** | Prefer one-pass library or codegen path; do not only “reuse buffers” |

**Document in the final report:** for each fix, `Docs: <url>` + `Example pattern: <snippet summary>` + `Harness was: <…>` + `Harness now: <…>`  
For harness bugs: `Docs: n/a (runner LABEL≠WORK)` + root-cause path.  
For library switches: `Docs: <old crate> + <new crate>` + wire-compat evidence + before/after ops.

---

## 4. Implement fixes

Only after step 3 for that suspect:

- Edit the wrapper **or** runner/batch cell as classified in 3.0.
- Prefer minimal, library-idiomatic changes (wrappers) or shared batch framing (runners).
- Do not expand scope to unrelated serializers.
- Keep suite isolation rules (see Non-negotiable #2).
- After LABEL≠WORK fixes, prefer re-bench with mode that includes **both** n=1 and n=N (`full` or matrix that has instance counts &gt; 1).

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
- **BATCH-AXIS** clean (or residual explained) for that language.
- **CROSS-LANGUAGE** no longer flags that language for under-size at n=N.
- No new error-CSV regressions for that language.
- Stream vs bytes still differ when stream is claimed.
- Spot-check: `size(message@n=100) / size(message@n=1)` roughly ~50–150 for binary codecs.

---

## 6. Expected vs remaining

For each original suspect, classify:

| Status | Meaning |
|--------|---------|
| **fixed** | Client/harness now matches contract; numbers re-checked |
| **expected** | Docs **and** ecosystem research confirm residual cost (e.g. pure-JS `cbor` slow; `dill` heavy; no faster wire-compatible crate) |
| **blocked** | No docs/examples found, or library bug with documented workaround only |
| **open** | Still suspicious after fix attempt |

Do **not** mark **fixed** without re-scan (or explicit `REVIEW_FIX=0` report-only mode).  
Do **not** mark **expected** for “fast at n=100” solely because package docs show a fast API — check LABEL≠WORK first.  
Do **not** mark **expected** for “binary slower than JSON” solely because the **official** crate’s only public API is two-step — complete §3.2b first.

---

## 7. Report format (user-facing)

```markdown
## Suspects found
| Lang | Serializer / harness | Signal | Client path |

## Research & actions
### <serializer or harness> (<lang>)
- Docs: <url or “n/a runner”>
- Recommended API / batch contract: …
- Harness issue: …
- Change: …
- Re-check: size/ops before → after; batch ratio size(n=N)/size(n=1); cross-lang note

## Languages clean
- … (only if within-group **and** batch-axis **and** cross-lang OK)

## Follow-ups
- …
```

---

## Helper scripts

| Script | Purpose |
|--------|---------|
| `scripts/scan-outliers.py` | Within-group size/ops outliers **+** batch-axis LABEL≠WORK **+** cross-lang size peers |

```bash
python3 .grok/skills/review-suspicious-results/scripts/scan-outliers.py --help
python3 .grok/skills/review-suspicious-results/scripts/scan-outliers.py --langs all --fixture message
```

Manual sanity (optional, when scanner output is thin):

```bash
# From stats JSON: median size message n=1 vs n=100 per language should differ by ~N
python3 -c "
import json, statistics as st
from pathlib import Path
for lang in ['c','csharp','python','rust','javascript','go','java','cpp']:
  p=Path(f'reports/stats_{lang}_latest.json')
  if not p.is_file():
    p=Path(f'dashboard/public/data/stats_{lang}_latest.json')
  if not p.is_file():
    continue
  g=json.load(open(p))['groups']
  for n in (1,100):
    s=[x['median_size_bytes'] for x in g if x.get('test_data')=='message'
       and x.get('data_type_instance_count')==n and (x.get('median_size_bytes') or 0)>0]
    if s: print(f'{lang:12} n={n:3} med_size={st.median(s):.0f}')
"
```

---

## Stop conditions

| Condition | Action |
|-----------|--------|
| No stats/logs for a requested language | Warn; skip that lang |
| Suspect found but no package docs/examples (wrapper case) | Mark **blocked**; do not invent API |
| BATCH-AXIS / CROSS-LANGUAGE harness bug | Fix runner; package docs are optional for that fix |
| Fix breaks isolation (suite types in wrappers) | Revert approach; use maps/Type bind |
| Re-bench fails hard | Stop; report failure |
| `REVIEW_FIX=0` | Research + report only |
| Within-group empty but batch/cross flags fire | **Not clean** — investigate harness |

---

## Quick checklist (print while working)

- [ ] Scanned all requested langs with `scan-outliers.py`  
- [ ] Read **within-group**, **BATCH-AXIS**, and **CROSS-LANGUAGE** sections  
- [ ] For batch/cross hits: opened **runner / batch_cell / run_v2** (not only wrappers)  
- [ ] For each wrapper suspect: opened official docs + code example  
- [ ] Compared example to harness client line-by-line  
- [ ] Verified `DataTypeInstanceCount` / fixture list length matches timed encode count  
- [ ] For “too slow”: split **ser vs deser**; flagged schema/binary **slower than same-lang JSON**  
- [ ] If API already optimal but still slow: **§3.2b ecosystem peer** research + wire-compat check  
- [ ] Fixed only with documented APIs (wrappers), better ecosystem crates, or honest batch framing (runners)  
- [ ] Re-benched affected langs (include n&gt;1 if batch fix)  
- [ ] Re-scanned outliers; batch ratio ~N; cross-lang size sane; Avro/schema vs JSON sense-check  
- [ ] Wrote research URLs / harness or library-switch root cause into the report  
- [ ] Did **not** declare clean on within-group-only empty  
- [ ] Did **not** mark **expected** for official two-step APIs without peer research  
