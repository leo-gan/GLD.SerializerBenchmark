# BSON

Specified at [bsonspec.org](https://bsonspec.org/spec.html).

The official MongoDB [bson-corpus](https://github.com/mongodb/specifications) is **CC BY-NC-SA 3.0 US** and **was not copied**. Cases here are recreated (names `n`, `s`, `kelp`; different cardinality).

## Versions

| Version | Note |
|---------|------|
| 1.0 | Document framing, int32, string, bool |
| 1.1 | Adds null and the same framing |
| 1.1 decimal128 | Type 0x13 |

## Python serializer

`bson` / pymongo if installed. The Python bench does not depend on it, so this row is absent until that package is present.

Catalog: `compliance/data/bson/`.
