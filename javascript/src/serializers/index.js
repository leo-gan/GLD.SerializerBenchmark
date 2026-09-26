/**
 * Serializer registry — modular by category.
 * prepare() runs outside the timed loop; serialize/deserialize use optimal package APIs.
 */

import { deepEqual } from '../data.js';
import { performance } from 'node:perf_hooks';
import { jsonSerializers } from './json.js';
import { binarySerializers } from './binary.js';
import { schemaSerializers } from './schema.js';
import { nativeSerializers } from './native.js';
import { modernSerializers } from './modern.js';
import { yamlSerializers } from './yaml.js';
import { dagrSerializers } from './dagr.js';

export const ALL_SERIALIZERS = [
  ...jsonSerializers(),
  ...binarySerializers(),
  ...schemaSerializers(),
  ...nativeSerializers(),
  ...modernSerializers(),
  ...yamlSerializers(),
  ...dagrSerializers(),
];

export { deepEqual, performance };
