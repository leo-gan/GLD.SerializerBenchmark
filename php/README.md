# PHP Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers

See [docs/php/index.md](../docs/php/index.md) for the inventory, PECL skip rules, and excluded candidates.

## Runner

```bash
./scripts/install-host-requirements.sh php
./php/scripts/run-benchmarks.sh smoke
./php/scripts/run-benchmarks.sh all-single
```

Output: `logs/php/YYYY-MM-DD-HHMMSS.csv` (`Language=php`, times in nanoseconds).
