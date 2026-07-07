# Serialization 101 — Deep Dives Plan (internal)

**Status:** approved outline for branch `refactor/docs-serializing-101`  
**Audience:** maintainers only — **not** published in MkDocs (lives outside `docs/`).  
**Related public pages:** `docs/theory/`, `docs/analysis/serialization_categories.md`

---

## Goal

Add a **Deep dives** layer under Serialization 101: short, problem-driven mechanism essays that sit **between** the high-level 101 home / three lenses and the suite categories + Results.

| Layer | Role | Location |
|-------|------|----------|
| 101 home + trade-off axes | Map, vocabulary | `docs/theory/index.md` |
| Historical / DS / Engineering | Long “lens” essays | `docs/theory/*_perspective.md` |
| **Deep dives (new)** | How/why mechanisms; decision-shaped comparisons | `docs/theory/deep-dives/` |
| Categories + methodology | Suite families, how we measure | `docs/analysis/` |
| Language Results | Measured numbers | `docs/<lang>/results.md` |

**Reading path:** skim 101 home → optional lens → deep dives when you need mechanism → categories + Results for numbers.

---

## Quality bar (course honesty)

1. No universal winners — always “under these constraints.”
2. Implementation > brand (e.g. JSON is not one speed).
3. Payload shape matters (graphs vs dense structs).
4. Compare within paradigm and within one language.
5. Security is first-class for native formats.
6. Prose numbers are illustrative; **Results** own suite truth.

---

## Article template (public pages)

```markdown
# {Title}

> One-sentence promise.

## Problem
## Short answer
## Mental model
## How it works
## Costs & constraints   # only axes that apply
## Real-world example
## In this suite         # preferred; link families / Results
## Common mistakes
## Key takeaways
```

Do **not** add Module / Prerequisites / Related header chrome, or Next / See also footers, on public pages; navigation and the hub own ordering.

| Article type | Emphasize | Soften |
|--------------|-----------|--------|
| Mechanism | Mental model, how it works | Long narrative |
| Comparison | Decision table, workloads | Bit-twiddling encyclopedia |
| Policy (evolution, trust) | Rules, failure modes | Forced microbenchmarks |
| Myth-bust | Counterexample, when each wins | Format catalog |

**Length:** ~800–1500 words (mechanism); ~1200–2000 (comparison). Longer content stays in lens docs.

**Diagram types:** bytes-on-the-wire strip · writer→bytes→reader · layout/offset · decision flowchart (playbook only).

---

## Curriculum

### Module A — Representation

| ID | File (slug) | Title | Core question | Ship |
|----|-------------|-------|---------------|------|
| A1 | *(deferred)* | Text vs binary on the wire | What do we optimize when leaving UTF-8? | Later — index tables may suffice |
| A2 | `memory-layout.md` | Memory layout, alignment, and endianness | Why in-memory objects are not portable bytes | **MVP** |
| A3 | `encode-decode-cost.md` | Where encode/decode time actually goes | Tokenization, numbers, allocations, copies | **MVP** |

### Module B — Contracts & change

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| B1 | `self-describing-vs-schema-dependent.md` | Self-describing vs schema-dependent | Who carries field identity? | **MVP** |
| B2 | `schema-evolution.md` | Schema evolution that doesn’t break readers | Forward/backward, defaults, reserved IDs | **MVP** |
| B3 | *(deferred)* | Trust boundaries: portable vs native | Why pickle/Java-ser are not interchange | Second wave |

### Module C — Families in practice

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| C1 | `dynamic-vs-idl-binary.md` | Dynamic binary vs IDL binary | Flexibility vs density & codegen (MsgPack/CBOR vs Protobuf) | **MVP** |
| C2 | *(deferred)* | Two schema cultures (Avro vs Protobuf) | Resolution vs field-number discipline | Second wave |
| C3 | `zero-copy.md` | Zero-copy layouts | What “no deserialize” means (FlatBuffers / Cap’n Proto case study) | **MVP** |

### Module D — Systems concerns

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| D1 | `compression-is-not-a-format.md` | Compression is not a format | When gzip helps; when format design dominates | **MVP** |
| D2 | *(deferred)* | Row vs columnar | Parquet/Arrow vs RPC messages | Second wave |
| D3 | *(deferred)* | Using this suite without fooling yourself | Same paradigm/language; methodology | Second wave |

### Explicit merges (from original proposal)

- Original “Text vs Binary” + “Why JSON is slower” → **A3** cost model (fair; not “JSON bad”); A1 only if index is insufficient.
- “Memory layout” + “Endianness” → **A2**.
- “Why Protobuf needs schemas” → mechanism inside **B1** (schema-dependent encoding), not Protobuf-only branding.
- “Zero-copy” + “Why FlatBuffers don’t deserialize” → **C3** only.
- Beauty-contest titles avoided; decision criteria + suite links required on comparisons.

---

## MVP order (implementation)

1. Scaffold `docs/theory/deep-dives/` + hub page; wire `mkdocs.yml` + 101 index links.
2. **A2** → **A3**
3. **B1** → **B2**
4. **C1** → **C3**
5. **D1** + nav/index polish

Commit after each major step (scaffold; each module; final polish as needed).

---

## Nav sketch (MkDocs)

```text
Serialization 101
  Theory & Practices
  Historical / Data Science / Engineering
  Deep dives
    Overview (hub)
    Memory layout, alignment, and endianness
    Where encode/decode time actually goes
    Self-describing vs schema-dependent
    Schema evolution that doesn’t break readers
    Dynamic binary vs IDL binary
    Zero-copy layouts
    Compression is not a format
```

Hub lists learning path + module grouping; each article links **Next** along MVP order.

---

## Non-goals

- Do not rewrite lens docs as articles.
- Do not duplicate full category tables from `serialization_categories.md`.
- Do not publish this plan file under the site.
- Do not claim suite winners in prose; link Results.
- Second-wave articles (A1, B3, C2, D2, D3) only after MVP is coherent.

---

## Done when

- [ ] Seven MVP articles + hub published in nav
- [ ] 101 `index.md` points at Deep dives with suggested order
- [ ] Each article uses the template and suite honesty rules
- [ ] This plan remains outside the MkDocs site
