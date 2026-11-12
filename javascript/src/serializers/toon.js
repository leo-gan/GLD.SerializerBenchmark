import { decode, encode } from '@toon-format/toon';
import { pkgVersion, baseSupports, bufToUtf8 } from './common.js';

/**
 * @toon-format/toon — official TypeScript TOON codec.
 * Timed path is UTF-8 encode/decode. Size is the byte length, not a token count.
 * https://github.com/toon-format/toon
 */
export const toonSer = {
  name: 'toon',
  version: pkgVersion('@toon-format/toon'),
  category: 'human',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(encode(value), 'utf8');
  },
  deserialize(buf) {
    return decode(bufToUtf8(buf));
  },
};

export function toonSerializers() {
  return [toonSer];
}
