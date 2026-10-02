import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CATALOG } from '../compliance-catalog.js';
import {
  serializerNameHtml,
  serializerSourceUrl,
  serializerVersion,
  setSerializerSources,
} from '../serializer-sources.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const catalogPath = join(root, 'config', 'serializer-sources.json');
const dashCopy = join(root, 'dashboard', 'public', 'data', 'serializer-sources.json');

function loadCatalog() {
  return JSON.parse(readFileSync(catalogPath, 'utf8'));
}

test('serializer-sources.json matches the dashboard public copy', () => {
  const a = readFileSync(catalogPath, 'utf8');
  const b = readFileSync(dashCopy, 'utf8');
  assert.equal(a, b);
});

test('every compliance-catalog serializer has a source URL', () => {
  const data = loadCatalog();
  const missing = [];
  for (const e of CATALOG) {
    const url = data.languages?.[e.language]?.[e.name]?.source_url;
    if (!url) missing.push(`${e.language}/${e.name}`);
  }
  assert.deepEqual(missing, []);
});

test('source URLs are http(s) and specifics are non-empty', () => {
  const data = loadCatalog();
  for (const [lang, items] of Object.entries(data.languages || {})) {
    for (const [name, rec] of Object.entries(items)) {
      assert.match(
        rec.source_url || '',
        /^https?:\/\//,
        `${lang}/${name} source_url`,
      );
      assert.ok((rec.specifics || '').length > 40, `${lang}/${name} specifics`);
    }
  }
});

test('serializerNameHtml wraps known names in a source link', () => {
  setSerializerSources({
    languages: {
      python: {
        orjson: { source_url: 'https://github.com/ijl/orjson', version: '3.11.6' },
      },
    },
  });
  assert.equal(serializerSourceUrl('python', 'orjson'), 'https://github.com/ijl/orjson');
  assert.equal(serializerVersion('python', 'orjson'), '3.11.6');
  assert.equal(serializerVersion('python', 'unknown'), '');
  const html = serializerNameHtml('python', 'orjson', 'orjson:3.10', { strong: true });
  assert.match(html, /href="https:\/\/github.com\/ijl\/orjson"/);
  assert.match(html, /<strong>orjson:3.10<\/strong>/);
  assert.equal(serializerNameHtml('python', 'unknown', 'unknown'), 'unknown');
});

test('encoding/json/v2 links to the v2 tree, and catalog docs cover a stale sources file', () => {
  const data = loadCatalog();
  setSerializerSources(data);
  const v1 = serializerSourceUrl('go', 'encoding/json');
  const v2 = serializerSourceUrl('go', 'encoding/json/v2');
  assert.equal(v1, 'https://github.com/golang/go/tree/master/src/encoding/json');
  assert.equal(v2, 'https://github.com/golang/go/tree/master/src/encoding/json/v2');
  assert.notEqual(v1, v2);
  const html = serializerNameHtml('go', 'encoding/json/v2', 'encoding/json/v2:go1.27.1', {
    strong: true,
  });
  assert.match(html, /href="https:\/\/github.com\/golang\/go\/tree\/master\/src\/encoding\/json\/v2"/);
  assert.match(html, /<strong>encoding\/json\/v2:go1.27.1<\/strong>/);

  setSerializerSources({
    languages: {
      go: {
        'encoding/json': {
          source_url: 'https://github.com/golang/go/tree/master/src/encoding/json',
        },
      },
    },
  });
  assert.equal(
    serializerSourceUrl('go', 'encoding/json/v2'),
    'https://pkg.go.dev/encoding/json/v2',
  );
  assert.match(
    serializerNameHtml('go', 'encoding/json/v2', 'encoding/json/v2:1.27.1'),
    /href="https:\/\/pkg.go.dev\/encoding\/json\/v2"/,
  );
  assert.equal(
    serializerSourceUrl('go', 'encoding/json'),
    'https://github.com/golang/go/tree/master/src/encoding/json',
  );
});

test('catalog versions match latest bench SerializerVersion when present', () => {
  const data = loadCatalog();
  const dataDir = join(root, 'dashboard', 'public', 'data');
  const mismatches = [];
  let compared = 0;
  for (const [lang, items] of Object.entries(data.languages || {})) {
    const gzPath = join(dataDir, `${lang}_latest.json.gz`);
    let payload;
    try {
      payload = JSON.parse(gunzipSync(readFileSync(gzPath)).toString('utf8'));
    } catch {
      continue;
    }
    const measured = new Map();
    for (const it of payload.configs?.serializers?.items || []) {
      if (it?.name && it?.version) measured.set(String(it.name), String(it.version));
    }
    for (const g of payload.stats?.groups || []) {
      if (g?.serializer && g?.serializer_version && !measured.has(String(g.serializer))) {
        measured.set(String(g.serializer), String(g.serializer_version));
      }
    }
    for (const [name, rec] of Object.entries(items)) {
      const want = measured.get(name);
      if (!want) continue;
      compared += 1;
      if (rec.version !== want) {
        mismatches.push(`${lang}/${name}: catalog=${rec.version} bench=${want}`);
      }
    }
  }
  assert.ok(compared > 200, `expected many version comparisons, got ${compared}`);
  assert.deepEqual(mismatches, []);
});
