#!/usr/bin/env node
/**
 * Node.js serializer benchmark runner — Data Model v2 only.
 * Usage: node src/runner.js <repetitions> [serializerFilter] [dataFilter]
 *
 * Official suite types: message, document, telemetry, strings, event.
 * Suite type ids: message, document, telemetry, strings, event.
 */
await import('./runner_v2.js');
