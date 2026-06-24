# JavaScript (Node.js) Ecosystem

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Harness

- `javascript/` (repository root)
- Logs: `logs/javascript/benchmark-log.csv`
- Requires Node ≥ 18
- `prepare()` compiles schemas / reuses encoder instances outside timed loops

## Serializers

See [JS tested serializers](javascript_tested_serializers.md).
