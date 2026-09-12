# YAML

YAML is not an RFC. The language is versioned on yaml.org: **1.0**,
**1.1**, **1.2**, with **1.2.2** the current 1.2 revision.

## Versions

| Version | Year | Parser-visible difference |
|---------|------|---------------------------|
| 1.1 | 2005 | `yes` / `no` / `on` / `off` are booleans. Sexagesimal integers (`1:2` → 62). What PyYAML implements. |
| 1.2 | 2009 | JSON is an official subset. JSON/Core schemas: `yes` is a **string**; no sexagesimal. |
| 1.2.2 | 2021 | Same language as 1.2; errata and clearer wording (tabs, duplicate keys, aliases). |

1.0 is omitted: it is not used in this suite’s industry set.

## What the cases cover

- Block and flow mappings / sequences
- Anchors and aliases
- Literal `|` and folded `>` scalars (1.2)
- Document start `---`
- 1.1 vs 1.2 implicit types (`yes`, `off`, `1:2`)
- Rejects: tab indentation, unmatched quotes / brackets, undefined alias

Catalog: `compliance/data/yaml/`.

## Python adapter

PyYAML `safe_load` is a **YAML 1.1** loader. It will:

- **pass** the 1.1 bool / sexagesimal cases
- **fail** the 1.2/1.2.2 “`yes` is a string” cases (it yields `True`)
- often **accept** duplicate keys (last wins) instead of erroring

That is expected and report-only.

## Official suite and the spec legend

The YAML spec legend is “freely copied, provided it is not modified.”
That is a poor fit for a test file we edit, so spec examples were not
copied. The official
[yaml-test-suite](https://github.com/yaml/yaml-test-suite) is MIT and
**is** vendored (`yts-*` ids). Original 1.1-vs-1.2 extras
(`harbor` / `kelp`) sit beside it. See [legal provenance](legal.md).
