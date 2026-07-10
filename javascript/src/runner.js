#!/usr/bin/env node
/**
 * Node.js serializer benchmark runner — Data Model v2 only.
 * Usage: node src/runner.js <repetitions> [serializerFilter] [dataFilter]
 *
 * V1 Person/EDI fixtures removed from the default run path.
 * Serializer packages under src/serializers/ are unchanged.
 */
await import('./runner_v2.js');
