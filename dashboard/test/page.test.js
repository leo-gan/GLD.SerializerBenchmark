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
