# Legal provenance

This page is the published summary. The full audit — every suite we
opened, its license, and the decision — is `compliance/LEGAL.md` in a
clone of the repository. IETF Appendix A notices live in
`compliance/THIRD_PARTY_NOTICES.md`.

## Rules we followed

1. Tests never depend on the network or on a third-party package for
   data.
2. We copy a suite only if it is clearly MIT, BSD, Apache-2.0, or IETF
   Code Components, **and** the copy is worth the notice burden.
3. We do **not** copy CC BY-NC-SA, “copy but do not modify” spec text,
   or W3C Test Suite License tests.
4. Otherwise we **recreate** the *rule* with new names, order, and
   cardinality, and we cite the section URL.

Official MIT / BSD / Apache suites that we *did* vendor live under
`compliance/data/` as catalog JSON. License texts are in
`compliance/vendor/`. Original extras stay `"provenance": "original-work"`.

## Suites we looked at

| Suite | License | Decision |
|-------|---------|----------|
| nst/JSONTestSuite | MIT | **Vendored** (`jts-*`). |
| yaml/yaml-test-suite | MIT | **Vendored** (`yts-*`). |
| YAML spec examples | “copy, do not modify” | **Not copied.** |
| toml-lang/toml-test | MIT | **Vendored** (`toml-1.0.0-*`, `toml-1.1.0-*`). |
| kawanet/msgpack-test-suite | MIT | **Vendored** (`mps-*`). |
| RFC 7049 / 8949 Appendix A | IETF Code Components (Revised BSD) | **Encodings used**, with the BSD notice. |
| cbor-wg/cbor-test-vectors | BSD-2-Clause | **Vendored** (`cbor-wg-*`). |
| amazon-ion/ion-tests | Apache-2.0 | **Vendored** (`ion-good-*`, `ion-bad-*`). |
| MongoDB BSON corpus | **CC BY-NC-SA 3.0 US** | **Not copied.** Recreated under `compliance/data/bson/`. |
| dmitry-ra/ubjson-test-suite | No OSI license | **Not copied.** Recreated under `compliance/data/ubjson/`. |
| W3C XML tests | W3C Test Suite License / 3-clause BSD | XML is out of scope. |
| protobuf `conformance/` | BSD-style | Legal, but it is a runner protocol. Not vendored. |
| Apache Avro tests | Apache-2.0 | Legal. Primitives rewritten from the spec. |

## How a recreated case differs from a spec listing

A YAML spec listing might show `First occurrence: &anchor Foo`. We
write:

```yaml
first: &harbor kelp
second: *harbor
```

Same *rule* (an alias refers to the most recent matching anchor).
Different identifiers, different cardinality, different surrounding
document. That is the “legal way to recreate data” this project
committed to.

## Not legal advice

A FAIL is our reading of a cited section against one library build. It
is not a statement that a vendor is out of compliance with a contract.
