# Serialization 301 — Plan (internal)

**Status:** draft outline (not yet implemented)  
**Audience:** maintainers only — **not** published in MkDocs  
**Program SoT:** `plans/COURSE_PROGRAM.md` (ladder, Bloom, topic ownership, hub template)  
**Sibling:** `plans/SERIALIZATION_401_PLAN.md` (senior elective — implementers)

---

## Role in the program

| | |
|--|--|
| **Number / title** | Serialization 301: Production Data Serialization |
| **Primary question** | What do I ship when constraints fight each other? |
| **Bloom band** | Analyze → Evaluate |
| **Sequence** | **Core** path: `101 → 201 → **301**`. Completes the default advanced sequence. |
| **Not this course** | Codec implementation, Protobuf wire cookbooks → **401** |

**One-line pitch:** Production serialization—trust, contracts, workloads, and honest measurement—for people who already know how formats work.

**Audience promise:** Recommend a serialization approach under multi-constraint scenarios and justify it with suite-honest evidence.

---

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | Serialization **101** (axes + at least one lens) |
| **Hard** | Serialization **201** — especially: schema-dependent vs self-describing, schema evolution, dynamic vs IDL, encode/decode cost, zero-copy, compression≠format *(or equivalent experience)* |
| **Out** | Do not re-teach 101/201 owned topics; one-line “Assumes 201: …” + link only |

---

## Learning outcomes (course-level)

By the end of 301, the learner should be able to:

1. **Analyze** trust boundaries and state when portable vs language-native formats are acceptable.  
2. **Distinguish** operational schema *cultures* (e.g. Avro-style resolution vs Protobuf field-number discipline) without re-deriving 201 wire rules.  
3. **Evaluate** workload fit (e.g. row vs columnar at system scale; polyglot contracts).  
4. **Critique** benchmark claims using this suite’s paradigm/language rules (D1).  
5. **Recommend** a family/approach under stated constraints and **justify** with categories + Results (capstones).  
6. **Identify** what this harness cannot answer.

---

## Quality bar

**Program honesty rules:** see `COURSE_PROGRAM.md`.  
**301-specific:**

1. Every major article ends with a **measurement plan** (what to check in the suite) and **what the suite cannot tell you**.  
2. Failure modes and constraint matrices over feature lists.  
3. Decision tables over mechanism encyclopedias (mechanisms → 201; wire labs → 401).

---

## Article templates

### Policy / systems

```markdown
# {Title}

> One-sentence promise.

## Problem
## Short answer
## Constraints that matter
## Decision frame
## Failure modes
## Real-world sketch
## In this suite
## What this suite cannot tell you
## Common mistakes
## Key takeaways
```

### Capstone (assessment-shaped)

```markdown
# Case study: {Scenario}

> One-sentence setting.

## Context & goals
## Non-goals / hard constraints
## Options on the table
## Trade-off matrix
## Recommendation (under these constraints)
## How to validate
## What would change the answer
## Key takeaways
```

Hub owns prereqs/order. Individual pages: at most one “Assumes 201: …” line.

| Type | Emphasize | Soften |
|------|-----------|--------|
| Policy | Rules, failure modes | Bit-level re-teach |
| Systems | Workload fit | Format catalog |
| Methodology | Honest use of Results | Replacing analysis docs |
| Capstone | Constraints → recommend → validate | History narrative |

**Length:** ~1000–1800 (policy/systems); ~1200–2000 (comparison); ~900–1500 (capstone).  
**Diagrams:** constraint matrix · trust boundary · producer→registry→consumer · measure/don’t-measure checklist.

---

## Curriculum

**Ship:** MVP | Second wave | Later. Topic ownership: `COURSE_PROGRAM.md`.

### H0 — Hub

| ID | File | Title | Ship |
|----|------|-------|------|
| H0 | `index.md` | Serialization 301 (syllabus hub) | **MVP** |

Hub = program syllabus template: audience, prereqs, outcomes, modules, honesty rules, next (**401** elective), back to 201.

### A — Trust & boundaries

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| A1 | `trust-boundaries.md` | Trust boundaries: portable vs native | When are native formats unacceptable as interchange? | **MVP** |
| A2 | `untrusted-input.md` | Untrusted input and parser risk | How do hostile payloads fail systems? | Second wave |
| A3 | `payload-surfaces.md` | Secrets, PII, and payload surfaces | Where do payloads leak? | Later |

### B — Contracts that survive years

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| B1 | `two-schema-cultures.md` | Two schema cultures: Avro vs Protobuf | Resolution culture vs field-number discipline (ops) | **MVP** |
| B2 | `schema-registries.md` | Schema registries and compatibility modes | BACKWARD / FORWARD / FULL in streams | Second wave |
| B3 | `public-api-contracts.md` | Public API contracts | When JSON still needs a hard contract | Second wave |
| B4 | `versioning-in-the-wild.md` | Versioning strategies in the wild | Dual-write, content-type, break playbooks | Later |

**B1:** requires 201 evolution; **do not** re-derive wire rules.

### C — Workload architecture

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| C1 | `row-vs-columnar.md` | Row vs columnar at system scale | When RPC codecs are wrong for lakes (and vice versa) | **MVP** |
| C2 | `polyglot-estates.md` | Polyglot estates | One product contract across runtimes | **MVP** |
| C3 | `rpc-and-messaging.md` | RPC and messaging payload design | Shape, fan-out, partial reads | Second wave |
| C4 | `zero-copy-in-production.md` | Zero-copy in production | Ops cost when mechanism is already known (201) | Second wave |
| C5 | `caching-and-queues.md` | Caching and queues | Blobs, native traps, multi-consumer | Later |

### D — Performance as engineering

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| D1 | `using-this-suite.md` | Using this suite without fooling yourself | Same paradigm/language; payload; warmups | **MVP** |
| D2 | `implementation-variance.md` | Implementation variance within a family | Choosing among libs—not building one (→401) | **MVP** |
| D3 | `latency-tails-and-gc.md` | Latency tails, allocations, and GC | p99 vs mean | Second wave |
| D4 | `compression-as-system-choice.md` | Compression as a system choice | Budgets; link 201 compression article | Second wave |

**D1** = flagship measurement lab (former deep-dives D3). Link methodology/metrics; do not duplicate catalogs.

### E — Capstones (aligned assessment)

| ID | File | Title | Ship |
|----|------|-------|------|
| E1 | `case-public-rest-api.md` | Case: public REST API | **MVP** |
| E2 | `case-internal-rpc.md` | Case: internal high-QPS RPC | **MVP** |
| E3 | `case-event-stream.md` | Case: event backbone | **MVP** |
| E4 | `case-analytics-lake.md` | Case: analytics lake | Second wave |
| E5 | `case-polyglot-boundary.md` | Case: cross-language boundary | Second wave |
| E6 | `case-faster-postmortem.md` | Case: “we need it faster” | Later |

Capstones **must** include validate + “suite cannot answer.”

### Absorbed from 201 deferred list

| Former ID | → 301 |
|-----------|-------|
| B3 Trust boundaries | A1 |
| C2 Two schema cultures | B1 |
| D2 Row vs columnar | C1 |
| D3 Suite honesty | D1 |

---

## MVP ship set

**Hub + 9 articles:** H0, A1, B1, C1, C2, D1, D2, E1, E2, E3.

1. Scaffold `docs/theory/301/`; top-level nav **Serialization 301**.  
2. Cross-links per `COURSE_PROGRAM.md` (201 → 301 default next; 301 → 401 elective).  
3. Write **D1** early (other articles lean on measurement honesty).  
4. A1 → B1 → C1 → C2 → D2 → E1 → E2 → E3.  
5. Hub polish (services vs data reading lists optional).

**Second wave:** A2, B2, B3, C3, C4, D3, D4, E4, E5.  
**Later:** A3, B4, C5, E6.

---

## Paths & nav

```text
docs/theory/301/
  index.md
  trust-boundaries.md
  two-schema-cultures.md
  row-vs-columnar.md
  polyglot-estates.md
  using-this-suite.md
  implementation-variance.md
  case-public-rest-api.md
  case-internal-rpc.md
  case-event-stream.md
```

```text
Serialization 301          # top-level tab
  Overview
  … MVP articles …
```

Full program nav: `COURSE_PROGRAM.md`.

---

## Suite docs (link, don’t copy)

| Need | SoT | 301 role |
|------|-----|----------|
| Families | `serialization_categories.md` | Decision frame |
| Methodology / metrics | analysis docs | Teach *use* (D1) |
| Inventories / numbers | lang Overview / Results | Evidence |
| Mechanisms | 201 | Prereq links |
| Wire / implement | 401 | Point implementers away |

---

## Non-goals

- Rewrite 101 lenses or 201 mechanism essays.  
- Duplicate analysis tables or methodology catalogs.  
- Format encyclopedia or ranked leaderboard.  
- Protobuf (or other) **implementation** series → **401**.  
- Require running the harness to finish reading (optional labs OK).  
- Publish this plan on the site.

---

## Done when (MVP)

- [ ] Hub + 9 MVP articles under **Serialization 301**  
- [ ] Outcomes + prereqs on hub match this plan / program SoT  
- [ ] Owned topics not re-taught from 201/401  
- [ ] Capstones E1–E3 include validate + limits  
- [ ] 201 hub points here as default next; hub points to 401 elective  
- [ ] Plan stays outside MkDocs  

---

## Open questions

1. Capstone tone: composite scenarios (default) vs named systems.  
2. Services vs data reading-list split on hub: optional for MVP.  
3. Path `docs/theory/301/` locked unless program moves to `docs/course/`.
