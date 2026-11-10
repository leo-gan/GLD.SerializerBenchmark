import { gzipSync } from 'node:zlib';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decodeJsonBytes, escapeHtml } from '../page.js';

test('escapeHtml encodes markup and treats null as empty', () => {
  assert.equal(escapeHtml('a<b>&"c'), 'a&lt;b&gt;&amp;&quot;c');
  assert.equal(escapeHtml(null), '');
  assert.equal(escapeHtml(undefined), '');
});

test('decodeJsonBytes reads plain JSON and gzip JSON', async () => {
  const plain = new TextEncoder().encode('{"a":1}');
  assert.deepEqual(await decodeJsonBytes(plain), { a: 1 });
  const gz = gzipSync(Buffer.from('{"b":2}'));
  assert.deepEqual(await decodeJsonBytes(gz), { b: 2 });
});

test('decodeJsonBytes does not deadlock on a large gzip payload', async () => {
  const rows = Array.from({ length: 1500 }, (_, i) => ({
    i,
    name: `serializer-${i}`,
    note: `case-${i}-abcdef`,
  }));
  const gz = gzipSync(Buffer.from(JSON.stringify({ rows })));
  const result = await Promise.race([
    decodeJsonBytes(gz),
    new Promise((_, reject) => setTimeout(() => reject(new Error('decode hung')), 2000)),
  ]);
  assert.equal(result.rows.length, 1500);
  assert.equal(result.rows[1499].name, 'serializer-1499');
});
