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

This first delivery **vendors no third-party suite**. Catalog files say
`"provenance": "original-work"` (CBOR Appendix A encodings add
`+ietf-appendix-A`).

## Suites we looked at

| Suite | License | Decision |
|-------|---------|----------|
| nst/JSONTestSuite | MIT | Legal to copy. **Not copied** — we needed RFC section URLs. |
| yaml/yaml-test-suite | MIT | Legal to copy. **Not copied** — original names instead. |
| YAML spec examples | “copy, do not modify” | **Not copied.** |
| toml-lang/toml-test | MIT | Legal to copy. **Not copied.** |
| kawanet/msgpack-test-suite | MIT | Legal to copy. **Not copied.** |
| RFC 7049 / 8949 Appendix A | IETF Code Components (Revised BSD) | **Encodings used**, with the BSD notice. |
| MongoDB BSON corpus | **CC BY-NC-SA 3.0 US** | **Cannot copy** into this MIT repo. Recreate if BSON is added. |
| W3C XML tests | W3C Test Suite License / 3-clause BSD | Do not vendor the “shall not be changed” tests. Recreate if XML is added. |
| protobuf `conformance/` | BSD-style | Legal, but it is a runner protocol. Out of scope here. |
| Apache Avro tests | Apache-2.0 | Legal. Out of scope here. |

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
