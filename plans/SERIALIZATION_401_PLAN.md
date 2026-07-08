# Serialization 401 — Plan (internal)

**Status:** draft outline (not yet implemented)  
**Audience:** maintainers only — **not** published in MkDocs  
**Program SoT:** `plans/COURSE_PROGRAM.md` (ladder, Bloom, topic ownership, hub template)  
**Sibling:** `plans/SERIALIZATION_301_PLAN.md` (core advanced — choosers)

---

## Role in the program

| | |
|--|--|
| **Number / title** | Serialization 401: Implementing Contemporary Serializers |
| **Primary question** | How do I implement or deeply integrate a real codec? |
| **Bloom band** | Apply → **Create** |
| **Sequence** | **Senior elective** after **201**. Complements core `101 → 201 → 301`; does **not** replace 301. |
| **Flagship format** | Protocol Buffers (shared `.proto`, multi-language suite) |
| **Not this course** | Multi-constraint *product* choice, registries-as-ops, suite methodology lab → **301** |

**One-line pitch:** Protobuf wire encoding and language runtime paths (Python, Rust, C), plus a thin subset lab—for serializer developers and deep integrators.

**Audience promise:** Trace wire bytes and a real runtime path; construct a correct **subset** encoder/decoder and validate it.

---

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | **101** + **201** (self-describing vs schema, encode cost, schema evolution, dynamic vs IDL) |
| **Soft (recommended)** | **301** — trust, polyglot judgment, honest measurement (link; do not re-teach) |
| **Skills** | Intermediate reading level in at least one of Python, Rust, C |
| **Out** | Full 301 case studies not required to start W1/L*/Lab1 |

---

## Learning outcomes (course-level)

By the end of 401 MVP, the learner should be able to:

1. **Encode and decode** (on paper / with tables) Protobuf wire structures: tags, varints, length-delimited, nested, simple repeated, skip unknowns.  
2. **Trace** the encode/decode path in **Python** (`google.protobuf`), **Rust** (`prost`), and **C** (`protobuf-c`), including buffer ownership.  
3. **Contrast** briefly classic C runtime vs embedded **nanopb** design axes (comparison box; not dual full paths).  
4. **Construct** a mini subset codec and **validate** against golden bytes and/or an official parser.  
5. **State** what the subset and articles deliberately omit (honesty).

---

## Depth model (locked)

| Decision | Choice |
|----------|--------|
| **Depth** | **B + thin lab**: wire + library/suite **paths**; mini subset lab—not full Protobuf reimplementation |
| **C stack** | **Primary: protobuf-c**; **nanopb**: short comparison box in L3 (full compare article = second wave) |
| **Languages MVP** | Python, Rust, C |

| Layer | In scope | Out of scope (v1) |
|-------|----------|-------------------|
| Shared wire | Tags, wire types, varint, len-delimited, nested, repeated, skip unknown | Full proto3 encyclopedia; gRPC; editions; all WKTs |
| Per-language B | Codegen entry, ownership, encode/decode path, suite wrap vs library | Full third-party source archaeology |
| Lab | Varint, string, nested, simple repeated; golden validate | Maps, oneofs, extensions, full Person fidelity, production hardening |

**Version honesty:** pin to suite deps; stable patterns over fragile line numbers; cite official encoding docs; no large third-party pastes.

---

## Quality bar

**Program honesty rules:** see `COURSE_PROGRAM.md`.  
**401-specific:**

1. Wire truth is shared; runtimes differ.  
2. Subset lab labels omissions.  
3. Suite harness ≠ reference design for Protobuf (integration illustration only).  
4. Results optional (cost centers only)—401 is not the benchmark course.  
5. One untrusted-decode note → link 301 A2 when present.  
6. Parallel language tours—not “Rust wins.”

---

## Article templates

### Wire / runtime path (B)

```markdown
# {Title}

> One-sentence promise.

## Problem
## Short answer
## Prerequisites          # e.g. Assumes 201: self-describing vs schema
## Mental model
## Step-by-step
## Buffers & ownership    # language articles
## In this suite
## Common mistakes
## What this article is not
## Key takeaways
```

### Lab (Create-level assessment)

```markdown
# Lab: {Title}

> Subset promise (explicit non-goals).

## Goal
## Subset (in / out)
## Wire checklist
## Steps (encode)
## Steps (decode)
## Validate
## Extension ideas
## Key takeaways
```

| Type | Emphasize | Soften |
|------|-----------|--------|
| Wire | Bytes, worked examples | Product API tour only |
| Language path | Codegen → encode → decode | Full library archaeology |
| Lab | Correct subset + validate | Feature completeness |

**Length:** ~1200–2000 (wire); ~1000–1800 (language); ~800–1400 (lab).  
**Diagrams:** tag/varint strip · nested lengths · ownership (who frees).  
**No** Previous/Next/See-also header or footer chrome on articles (nav + hub only; see `COURSE_PROGRAM.md`).

---

## Curriculum

Topic ownership: `COURSE_PROGRAM.md` (wire/paths/lab = **401 only**).

### H0 — Hub

| ID | File | Title | Ship |
|----|------|-------|------|
| H0 | `index.md` | Serialization 401 (syllabus hub) | **MVP** |

Hub = program syllabus template + depth model + 301 recommended + “this is not 301.”

### W — Shared wire

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| W1 | `protobuf-wire-format.md` | Protobuf wire format step-by-step | How do tags and nested messages become bytes? | **MVP** |

Link 201 for *concepts*; W1 owns **byte-level** procedure. Teaching mini-message preferred over full Person.

### L — Language paths (B)

| ID | File | Title | Core question | Ship |
|----|------|-------|---------------|------|
| L1 | `protobuf-python.md` | Python: google.protobuf path | Generated messages, serialize/parse, CPython ownership | **MVP** |
| L2 | `protobuf-rust-prost.md` | Rust: prost path | `Message` trait, prost-build, typed codec | **MVP** |
| L3 | `protobuf-c-protobuf-c.md` | C: protobuf-c path | Pack/unpack, memory discipline; **nanopb box** | **MVP** |
| L4 | `protobuf-c-nanopb-compare.md` | nanopb vs protobuf-c | Embedded vs classic design | Second wave |

| Lang | Suite anchor | Article |
|------|--------------|---------|
| Python | `protobuf` + generated pb2 | L1 |
| Rust | `prost` / `build.rs` + shared `.proto` | L2 |
| C | **protobuf-c** primary; nanopb box | L3 |

**Write order:** W1 → **L1 → L2 → L3** (swap L1/L2 only for authoring convenience).

### Lab — Create

| ID | File | Title | Ship |
|----|------|-------|------|
| Lab1 | `lab-mini-protobuf-encoder.md` | Lab: mini Protobuf subset encoder/decoder | **MVP** |

| In (v1) | Out |
|---------|-----|
| Varint scalars as needed | Full scalar matrix / zigzag unless required |
| Length-delimited string | Large arbitrary bytes blobs |
| Nested message | any / WKTs |
| Simple repeated (unpacked) | Packed as stretch only |
| Skip unknown varint / len-delimited | Full unknown-field store |

**Validate:** golden bytes table and/or official Python/protobuf-c parse.  
**Lab medium default:** pseudocode + Python golden helper.

### X — Cross-language

| ID | File | Title | Ship |
|----|------|-------|------|
| X1 | `protobuf-cross-language-fidelity.md` | Same bytes, three runtimes | Second wave |

**X1 vs 301 C2:** 401 = byte/fidelity discipline; 301 = product polyglot choice. No merge.

---

## MVP ship set

**Hub + 5 articles:** H0, W1, L1, L2, L3, Lab1.

1. Scaffold `docs/theory/401/`; top-level nav **Serialization 401**.  
2. **W1** first.  
3. L1 → L2 → L3.  
4. Lab1 after W1 (may parallel last L*).  
5. Cross-links per program: 201 → 401 elective; 301 ↔ 401 mutual one-liners.

**Second wave:** L4, X1.  
**Later:** second format track only after Protobuf MVP is coherent (out of this plan’s MVP).

---

## Paths & nav

```text
docs/theory/401/
  index.md
  protobuf-wire-format.md
  protobuf-python.md
  protobuf-rust-prost.md
  protobuf-c-protobuf-c.md
  lab-mini-protobuf-encoder.md
```

```text
Serialization 401
  Overview
  Protobuf wire format step-by-step
  Python: google.protobuf path
  Rust: prost path
  C: protobuf-c path
  Lab: mini Protobuf subset encoder/decoder
```

---

## Suite code (illustrate, don’t over-couple)

| Asset | Use |
|-------|-----|
| `schemas/benchmark_data.proto` | Anchor; prefer teaching mini-message in W1/Lab1 |
| Python / Rust / C Protobuf registrations | “In this suite” pointers |
| Results | Optional cost-center links only |
| 201 | Prereq mechanism links only |
| 301 | Soft prereq; security/polyglot links |

---

## Non-goals

- Full Protobuf reimplementation or in-tree competing codec as the course.  
- Dual full C paths (protobuf-c + nanopb) in MVP.  
- Chooser case studies, registry ops, suite-honesty lab (→ **301**).  
- API-only “how to use Protobuf” without wire.  
- Second format track before Protobuf MVP done.  
- Publish this plan on the site.

---

## Done when (MVP)

- [ ] Hub + W1 + L1 + L2 + L3 + Lab1 under **Serialization 401**  
- [ ] Outcomes, hard/soft prereqs, depth model on hub  
- [ ] Lab documents subset in/out + validation  
- [ ] No 301 chooser content duplicated  
- [ ] 201/301 hubs link elective correctly  
- [ ] Plan stays outside MkDocs  

---

## Open questions (defaults set)

1. Pilot L1 vs L2 first — default **L1 → L2 → L3**.  
2. Lab medium — default **pseudocode + Python golden helper**.  
3. Mini-message vs Person — default **dedicated mini-message**.  
4. Path `docs/theory/401/` locked with program.
