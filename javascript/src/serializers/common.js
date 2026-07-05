import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);

/** Installed npm package version for CSV SerializerVersion (full semver). */
export function pkgVersion(packageName) {
  try {
    return require(`${packageName}/package.json`).version || '';
  } catch {
    /* package.json may be blocked by "exports"; walk up from resolved entry */
  }
  try {
    let dir = dirname(require.resolve(packageName));
    for (let i = 0; i < 8; i++) {
      try {
        const raw = readFileSync(join(dir, 'package.json'), 'utf8');
        const v = JSON.parse(raw).version;
        if (v) return String(v);
      } catch {
        /* continue */
      }
      const parent = dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch {
    /* missing package */
  }
  return '';
}

export function baseSupports(name) {
  return name !== 'ObjectGraph';
}

/** JSON-clone to strip non-JSON types before schemaless binary codecs if needed. */
export function jsonClone(value) {
  return JSON.parse(JSON.stringify(value));
}
