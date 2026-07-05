import v8 from 'node:v8';

export const v8Ser = {
  name: 'v8-serializer',
  version: `v8-${process.versions.v8}`,
  category: 'native',
  // Supports ObjectGraph (cycles) via V8 serializer
  supports: () => true,
  prepare() {},
  serialize(value) {
    return v8.serialize(value);
  },
  deserialize(buf) {
    return v8.deserialize(Buffer.from(buf));
  },
};

export function nativeSerializers() {
  return [v8Ser];
}
