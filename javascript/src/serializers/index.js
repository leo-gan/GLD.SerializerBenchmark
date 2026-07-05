/**
 * Serializer registry — modular by category (json / binary / schema / native).
 * Each entry uses optimal package APIs; prepare() runs outside the timed loop.
 */

import { deepEqual } from '../data.js';
import { performance } from 'node:perf_hooks';
import { jsonSerializers } from './json.js';
import { binarySerializers } from './binary.js';
import { schemaSerializers } from './schema.js';
import { nativeSerializers } from './native.js';

export const ALL_SERIALIZERS = [
  ...jsonSerializers(),
  ...binarySerializers(),
  ...schemaSerializers(),
  ...nativeSerializers(),
];

export { deepEqual, performance };
