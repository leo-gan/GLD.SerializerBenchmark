# Legal provenance of the compliance corpus

This file is the audit trail for every byte under `compliance/data/`.
It records what we looked at, what we did **not** copy, why, and how the
cases that *are* in the tree were produced.

This repository is MIT-licensed. Anything vendored into it must be
compatible with MIT redistribution. “Compatible” here means: we can
ship the bytes, keep required notices, and we do not take on a
Share-Alike or Non-Commercial obligation that would relicense the
project.

## Policy (short)

1. **No runtime dependency** on a third-party test suite. Tests never
   clone, pip-install, or HTTP-fetch corpus data.
2. **Copy only when the license is clearly MIT, BSD, Apache-2.0, or
   IETF Code Components (Revised BSD)** *and* the copy is useful.
3. **Do not copy** material under CC BY-NC-SA, the unmodified-YAML-spec
   “copy but do not modify” legend, or the W3C Test Suite License
   (tests shall not be changed).
4. When a copy would be legally risky, **recreate** cases from the
   published normative rule: change names, key order, cardinality, and
   narrative. Cite the section. Do not paraphrase a copyrighted example
   so closely that it is a derivative of that example.
5. Facts about a format (the hex for integer `0` in CBOR is `0x00`) are
   not copyrightable. The *selection and arrangement* of a third-party
   suite can be. Official suites that are MIT or BSD are copied into
   `compliance/data/` as catalog JSON (no git submodule, no download at
   run time). License texts live in `compliance/vendor/`.

## What we researched

### IETF RFCs (JSON, I-JSON, CBOR)

| Document | Role | Status |
|----------|------|--------|
| [RFC 4627](https://www.rfc-editor.org/rfc/rfc4627) | First IETF JSON (2006). Top-level **object or array** only. | Obsoleted by 7159 |
| [RFC 7159](https://www.rfc-editor.org/rfc/rfc7159) | JSON as any value; UTF-8 / UTF-16 / UTF-32. | Obsoleted by 8259 |
| [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) | Current JSON, **STD 90**. Interchange **MUST be UTF-8**. Aligned with ECMA-404 2nd ed. | Internet Standard |
| [RFC 7493](https://www.rfc-editor.org/rfc/rfc7493) | **I-JSON** profile (not a fourth grammar). | Proposed Standard |
| [RFC 7049](https://www.rfc-editor.org/rfc/rfc7049) | Original CBOR. | Obsoleted by 8949 |
| [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949) | Current CBOR, **STD 94**. | Internet Standard |

**IETF Trust Legal Provisions (TLP 5.0)**

- *Prose* of an RFC may be quoted with attribution. Substantial
  reproduction of RFC text (more than about one-fifth of a document)
  must keep IETF legends. We quote **short normative sentences** and
  link the section; we do not republish RFCs.
- *Code Components* (ABNF, tables of values, `<CODE BEGINS>` blocks)
  in RFCs published on or after 2008-11-10 are licensed under the
  **Revised BSD License**. Extraction requires either the BSD text or
  the TLP §6.d legend.
- RFC 8949 / 7049 **Appendix A** is a table of diagnostic notation ↔
  encoded bytes. Tables of values are listed as Code Components
  ([IETF Trust list](https://trustee.ietf.org/documents/trust-legal-provisions/code-components-list-3/)).
  We use a **subset** of those encodings with original case ids and
  titles, and we reproduce the Revised BSD notice in
  `THIRD_PARTY_NOTICES.md`.

Sources:

- <https://trustee.ietf.org/documents/trust-legal-provisions/tlp-5/>
- <https://trustee.ietf.org/about/faq/> (“Can I use code that is included in IETF Documents?”)

### JSONTestSuite (nst/JSONTestSuite)

- Comprehensive RFC 8259 parse suite. **MIT** (Copyright 2016 Nicolas Seriot).
- Copying would have been legal (keep the MIT notice).
- **Now vendored** into `compliance/data/json/rfc{4627,7159,8259}.json`
  (`jts-*` ids). `y_` → accept, `n_` → reject, `i_` → `expect: any`
  (implementation-defined, recorded, not scored). Section URLs are
  mapped from the file name onto RFC 8259 §2 / §4 / §5 / §6 / §7.
  License: `compliance/vendor/JSONTestSuite.MIT.txt`.

### YAML

| Version | Date | Notes |
|---------|------|--------|
| 1.0 | 2001 | Historical; rarely implemented today |
| 1.1 | 2005 | PyYAML’s default model (`yes`/`no` booleans, sexagesimal) |
| 1.2 | 2009 | JSON as official subset |
| 1.2.2 | 2021 | Current 1.2 revision (errata / editorial). Still “1.2”. |

- The YAML specification text says: *“This document may be freely
  copied, provided it is not modified.”* That is **not** an OSI-approved
  license. Copying spec examples into a modified test file is the
  modification the legend forbids. See
  [yaml/yaml-spec#333](https://github.com/yaml/yaml-spec/issues/333).
- The official [yaml/yaml-test-suite](https://github.com/yaml/yaml-test-suite)
  is **MIT** (Copyright 2016–2020 Ingy döt Net).
- **Now vendored** (`yts-*` ids) from `src/*.yaml`. `fail` / `error`
  tags → reject; others → accept. License:
  `compliance/vendor/yaml-test-suite.MIT.txt`.
- Original extras (`harbor` / `kelp`) remain for 1.1 vs 1.2 implicit types.

### TOML

- Official suite: [toml-lang/toml-test](https://github.com/toml-lang/toml-test), **MIT**.
- Versions in industry: **0.5.0** (2018, dotted keys), **1.0.0** (2021,
  first stable), **1.1.0** (trailing commas / newlines in inline
  tables, `\xHH`).
- **Now vendored** (`toml-1.0.0-*`, `toml-1.1.0-*`) from
  `tests/files-toml-1.0.0` and `files-toml-1.1.0`. License:
  `compliance/vendor/toml-test.MIT.txt`.
- TOML 0.5.0 has no official file list; original extras stay.

### MessagePack

- Living spec: [msgpack/msgpack `spec.md`](https://github.com/msgpack/msgpack/blob/master/spec.md).
  Industry “versions” are additive revisions, not numbered RFCs:
  **pre-2013 raw**, **2013 str/bin/ext**, **2017 timestamp ext −1**.
- Community dataset [kawanet/msgpack-test-suite](https://github.com/kawanet/msgpack-test-suite)
  is **MIT**. **Now vendored** (`mps-*` ids) from
  `dist/msgpack-test-suite.json`. License:
  `compliance/vendor/msgpack-test-suite.MIT.txt`.

### Suites we considered and rejected for this delivery

| Suite | License | Why not copied |
|-------|---------|----------------|
| MongoDB [BSON corpus](https://github.com/mongodb/specifications) | **CC BY-NC-SA 3.0 US** | **Not copied.** Recreated under `compliance/data/bson/`. |
| W3C XML / XSD test suites | W3C Test Suite License **or** W3C 3-clause BSD | Test Suite License: “The tests themselves shall NOT be changed.” Dual BSD exists but the documents are still W3C-copyrighted. Recreate if XML is added. |
| Google protobuf `conformance/` | BSD-style (Google) | Legal to copy, but it is a **runner protocol** plus generated messages, not a static catalog file. Out of scope for the text+IETF-binary first cut. |
| Apache Avro `share/test` | Apache-2.0 | Legal to copy. Out of scope for this first cut. |
| [cbor-wg/cbor-test-vectors](https://github.com/cbor-wg/cbor-test-vectors) | BSD-2-Clause | **Now vendored** (`cbor-wg-*` ids) from `tests/rfc8949/{good,bad}.edn`. License: `compliance/vendor/cbor-test-vectors.BSD-2-Clause.txt`. |
| [dmitry-ra/ubjson-test-suite](https://github.com/dmitry-ra/ubjson-test-suite) | No OSI license in tree | Do not copy. |
| MongoDB [BSON corpus](https://github.com/mongodb/specifications) | **CC BY-NC-SA 3.0 US** | **Not copied.** `compliance/data/bson/` is original recreation. |

XML is out of scope (user request). W3C XML tests were never imported.

### Protocol Buffers / Avro / FlatBuffers

- Encoding rules from protobuf.dev, avro.apache.org, and flatbuffers.dev.
- Cases are **original-work** (new field numbers, names `kelp` / `harbor`).
- Google `conformance/` was not vendored (runner protocol, not a static catalog).
- Apache Avro `share/test` was not copied; primitives were rewritten from the spec.

## How original cases were written

For each MUST / MUST NOT / SHOULD rule we wanted:

1. Read the published section (RFC HTML, yaml.org, toml.io, msgpack spec).
2. Write a **new** input: different keys (`harbor`, `kelp`, `count`,
   `berth`), different order, different cardinality than any spec
   listing we saw.
3. Attach `section`, `section_title`, `section_url`, and a short
   `paragraph` that states the rule (not a copy of a page of RFC prose).
4. Set `expect` to `accept` or `reject` from the rule, not from what
   Python’s parser happens to do.

CBOR Appendix A is the exception: the *encodings* are the IETF table.
The case ids (`cbor8949-app-1000`) and titles are ours. See
`THIRD_PARTY_NOTICES.md`.

## What “report-only” means legally

A FAIL in this corpus is a statement that **this library, on this
input, did not match our reading of that section**. It is not a claim
that the library is unlicensed, unsafe, or unfit. Many production
parsers deliberately accept RFC-invalid input (NaN, top-level scalars
under a 4627 reading, YAML 1.1 bools when the caller asked for 1.2).

Do not treat the catalog as legal advice about any library’s
compliance obligations.

## Keeping this file honest

When someone adds a format or vendors a suite:

1. Record the upstream URL, license, and copyright years here.
2. If vendoring MIT/BSD/Apache: copy the license into
   `THIRD_PARTY_NOTICES.md` and keep copyright lines.
3. If the license is NC, SA, “do not modify”, or missing: **recreate**.
4. Never add a git submodule or a test-time download.
