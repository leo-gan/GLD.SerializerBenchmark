import v8 from 'node:v8';
import { asBuffer } from './common.js';

export const v8Ser = {
  name: 'v8-serializer',
  version: `v8-${process.versions.v8}`,
  category: 'native',
  // Flat ObjectGraph + live cycles both work; suite uses flat index edges.
  supports: () => true,
  prepare() {},
  serialize(value) {
    return v8.serialize(value);
  },
  deserialize(buf) {
    // v8.deserialize accepts Buffer; avoid double-wrap.
    return v8.deserialize(asBuffer(buf));
  },
};

export function nativeSerializers() {
  return [v8Ser];
}
