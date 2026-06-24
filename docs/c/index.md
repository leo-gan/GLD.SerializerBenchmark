# C Ecosystem

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The harness normalizes fixtures into C structs, then times library-specific encode/decode.

## Harness

- `c/` (repository root)
- Logs: `logs/c/benchmark-log.csv`
- Build: CMake, C11

## Caveat

Default CI build uses **portable minimal codecs** labeled with real library names so the pipeline runs without distro packages. For paper results, vendor/link real libraries (see [C tested serializers](c_tested_serializers.md)).
