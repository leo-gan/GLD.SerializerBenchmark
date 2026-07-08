# Serialization course program — master plan (internal)

**Status:** draft curriculum SoT for maintainers  
**Audience:** maintainers only — **not** published in MkDocs  
**Scope:** align Serialization **101 → 201 → 301 → 401** as one program  
**Per-course detail:** live public docs (101, 201); `SERIALIZATION_301_PLAN.md`; `SERIALIZATION_401_PLAN.md`  
**Historical:** `DEEP_DIVES_PLAN.md` = original 201 design (still useful for article list; naming superseded)

---

## Design standards (university practice)

Plans follow common higher-ed course-design practice:

| Practice | Application here |
|----------|------------------|
| **Backward design** | Course outcomes → modules/articles that evidence them → hub “assessments” (checklists / case studies / lab) |
| **Bloom’s taxonomy (cognitive)** | Numbering tracks cognitive demand: remember/understand → apply → analyze/evaluate → create |
| **Measurable outcomes** | Verb + content + condition (“Under multi-constraint scenarios, *recommend* a family and *justify* with suite-valid evidence”) |
| **Prerequisites** | Explicit prior courses; no silent re-teaching of owned topics |
| **Constructive alignment** | Article type matches level (map ≠ case study ≠ implementer lab) |
| **Single ownership** | Each topic has one home course; others **link**, never re-derive |
| **Syllabus-shaped hubs** | Every course hub: description, audience, prereqs, outcomes, modules, honesty rules, “where to go next” (hub only) |

Sources of practice (not copied text): learning-outcome design via Bloom’s hierarchy (e.g. Stanford Teaching Commons; standard instructional-design syllabi).

---

## Program map

```text
                    ┌─────────────────────────────────────┐
                    │         CORE SEQUENCE               │
  Serialization 101 ──► Serialization 201 ──► Serialization 301
  (foundations)         (mechanisms)           (production judgment)
                    └─────────────────────────────────────┘
                                              │
                              recommended for context
                                              │
                                              ▼
                                    Serialization 401
                                    (senior elective:
                                     implement codecs)
```

| # | Formal title | Primary question | Bloom band (target) | Audience |
|---|--------------|------------------|---------------------|----------|
| **101** | Foundations of Data Serialization | What is it, and what axes matter? | Remember → Understand *(intro Apply)* | Anyone |
| **201** | Serialization Mechanisms | How and why do formats work this way? | Understand → Apply | After 101 |
| **301** | Production Serialization | What do I ship under conflicting constraints? | Analyze → Evaluate | After 201 |
| **401** | Implementing Serializers | How do I implement / integrate a real codec? | Apply → **Create** | After 201; **301 recommended** |

**Sequencing rule (locked):**

1. **Core path (default):** `101 → 201 → 301`.  
2. **401 is a senior elective**, not a replacement for 301.  
3. **401 hard prereq:** 101 + 201 (schema-dependent, encode cost, evolution, dynamic vs IDL).  
4. **401 soft prereq:** 301 (trust, polyglot, honest measurement)—link, do not re-teach; allow implementers to enter 401 after 201 if they only need wire/path/lab.  
5. **No parallel “second 301”:** chooser content stays in 301; implementer content stays in 401.

**Nav (public):** top-level tabs for 101, 201, 301, 401 when each exists. 201 may remain path `docs/theory/deep-dives/` until a later path rename.

---

## Program-level learning outcomes

By completing the **core** (101–301), a learner can:

1. **Explain** serialization/deserialization and the core trade-off axes (101).  
2. **Interpret** format history and workload lenses without treating brand names as winners (101).  
3. **Apply** mechanism models (layout, cost, schema identity, evolution, zero-copy, compression) to concrete questions (201).  
4. **Analyze** production constraints (trust, contracts, workloads, measurement validity) (301).  
5. **Evaluate** and **recommend** a serialization approach under stated constraints, with suite-honest evidence (301).

By completing **401** (elective), a learner can additionally:

6. **Trace** Protobuf wire encoding and a language runtime encode/decode path (401).  
7. **Create** a correct **subset** encoder/decoder and validate it against golden bytes or an official parser (401).

---

## Topic ownership (anti-duplication matrix)

**Rule:** the owner course *defines* the topic. Other courses may **link** in one sentence or a “Assumes N0x: …” line—no second full treatment.

| Topic | **Owner** | 101 | 201 | 301 | 401 |
|-------|-----------|-----|-----|-----|-----|
| Definition of ser/deser; core axes | **101** | define | link | link | link |
| Historical / DS / Eng lenses | **101** | full | link | link | — |
| Memory layout, endianness | **201** | axis only | full | — | link if needed |
| Encode/decode cost centers | **201** | mention | full | use in D* | cost context only |
| Self-describing vs schema-dependent | **201** | axis | full | — | prereq for W1 |
| Schema evolution *rules* (fwd/back, field ids) | **201** | — | full | operational *cultures* only | — |
| Dynamic binary vs IDL binary | **201** | — | full | use in cases | — |
| Zero-copy *mechanism* | **201** | — | full | production tradeoffs only | — |
| Compression ≠ format | **201** | — | full | system budgets only | — |
| Trust boundaries / native formats | **301** | warn briefly | deferred→301 | full | security note + link |
| Untrusted input / parser risk | **301** | — | — | full | one note + link |
| Two schema *cultures* (Avro vs Pb ops) | **301** | — | — | full | — |
| Registries, public API contracts, versioning ops | **301** | — | — | full | — |
| Row vs columnar *at system scale* | **301** | axis | deferred→301 | full | — |
| Polyglot estate *product* choice | **301** | — | — | full | fidelity *bytes* in X1 only |
| Using this suite honestly | **301** | point to Results | point | full lab | Results optional |
| Implementation variance (choose a lib) | **301** | — | — | full | — |
| Capstone decision cases | **301** | — | — | full | — |
| Protobuf **wire** step-by-step | **401** | — | concept only | choose Pb | full W1 |
| Language runtime **paths** (Py/Rust/C) | **401** | — | — | — | full L* |
| Mini encoder **lab** | **401** | — | — | — | full Lab1 |
| Four families / category tables | **analysis** | link | link | link | link |
| Methodology / metrics catalog | **analysis** | link | link | teach *use* (D1) | — |
| Per-language inventories / Results | **lang docs** | link | link | evidence | optional |

### Deferred 201 items — single home

| Former deep-dives ID | Topic | Final home |
|----------------------|-------|------------|
| B3 | Trust boundaries | **301 A1** |
| C2 | Two schema cultures | **301 B1** |
| D2 | Row vs columnar (system) | **301 C1** |
| D3 | Using this suite honestly | **301 D1** |

Do not re-list these as 201 second-wave once 301 exists.

---

## Bloom alignment by course (what “good” looks like)

| Course | Typical article verbs | Avoid |
|--------|----------------------|--------|
| **101** | define, describe, identify, compare (axes), outline | multi-constraint production design |
| **201** | explain, model, distinguish, apply (to a mechanism question) | full production playbooks; implementer labs |
| **301** | analyze, evaluate, recommend, justify, critique (benchmarks) | re-teaching wire/layout; coding a codec |
| **401** | trace, implement, validate, construct (subset) | format beauty contests; registry ops case studies |

---

## Shared syllabus template (every course hub)

Public hubs should use the same skeleton (titles may vary slightly):

```markdown
# Serialization N0x: {Formal title}

> One-line pitch.

## Who this is for
## Prerequisites
## Learning outcomes          # 3–6 measurable bullets
## How this course fits the program   # link ladder; next course
## Modules / path
## Honesty rules              # program rules + course-specific
## Assessment (self-check)    # optional: checklist, case, lab
```

**Navigation chrome (locked — user preference):**

- **Do not** put Previous / Next / “See also” / module chrome in **article headers or footers**.  
- Ordering lives in **nav** + **course hub** only.  
- In-body links are fine when teaching (e.g. “see schema evolution”), not as pager bars.  
- Hubs may have a short **Where to go next** list (not a Next|Prev table on every page).

**Program honesty rules (all courses):**

1. No universal winners — always under stated constraints.  
2. Implementation beats brand name.  
3. Payload shape matters.  
4. Compare within paradigm and within one language before cross claims.  
5. Security/trust is first-class where relevant.  
6. Prose numbers are illustrative; **Results** own suite truth.  
7. Link owners; do not duplicate owned topics.

---

## Cross-course navigation (locked)

| From | Points to |
|------|-----------|
| 101 end / next steps | 201 (mechanisms); categories + Results |
| 201 end | **301** (default next); **401** (implementer elective) |
| 301 hub | Back: 201; Elective: 401; Lab: analysis/Results |
| 401 hub | Prereq: 201; Recommended: 301; Do not substitute for 301 |

---

## Public paths (canonical)

| Course | Path | Nav label |
|--------|------|-----------|
| 101 | `docs/theory/index.md` + perspectives | Serialization 101 |
| 201 | `docs/theory/deep-dives/` | Serialization 201 |
| 301 | `docs/theory/301/` | Serialization 301 |
| 401 | `docs/theory/401/` | Serialization 401 |
| Suite (not a course) | `docs/analysis/`, `docs/<lang>/` | Benchmarks / languages |

---

## Duplication & consistency fixes (program review)

| Issue | Fix |
|-------|-----|
| 201 hub still says “how to **choose** under constraints” | Chooser language → **301**; 201 = mechanisms only (public copy follow-up) |
| 301/401 plans each restate full ladder | Ladder SoT = **this file**; 301/401 keep short “role + prereq” only |
| 401 “optional 301” vs sequential numbers | 401 = **elective after 201**; 301 = **core** advanced; soft-require 301 |
| Overlap risk: 201 evolution vs 301 schema cultures | 201 = wire/rules; 301 = registry/culture/ops |
| Overlap risk: 201 zero-copy vs 301 zero-copy in prod | 201 = mechanism; 301 C4 = ops only |
| Overlap risk: 301 D2 vs 401 | D2 = *select* among implementations; 401 = *build/integrate* one path |
| Overlap risk: 401 W1 vs 201 B1 | W1 = byte cookbook; 201 = who carries field identity |
| 301 MVP too broad vs one semester | Cap MVP at hub + 9 articles; second wave explicit |
| Multiple quality bars | Shared rules here; course-specific bullets only in 301/401 plans |
| DEEP_DIVES_PLAN vs 201 naming | Treat deep-dives plan as historical; program uses **201** |

---

## Implementation order (program)

1. Keep 101/201 content stable; fix 201 hub chooser wording when touching docs.  
2. Ship **301** MVP (chooser core completes the sequence).  
3. Ship **401** MVP (elective; W1 → L* → Lab1).  
4. Wire hubs and README to this ladder.  
5. Path rename `deep-dives/` → `201/` only as a later, explicit migration (not required for consistency of *titles*).

---

## Done when (program)

- [ ] This file is the only full ladder + ownership matrix  
- [ ] 301 and 401 plans reference this file; no conflicting prereq stories  
- [ ] Each topic in the matrix has one owner  
- [ ] Public hubs (as they ship) use the syllabus template + program honesty rules  
- [ ] 201 public copy does not claim production multi-constraint *choice* as its job  
