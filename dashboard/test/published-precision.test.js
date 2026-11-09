/**
 * Published stats keep only the digits the tables print.
 * The analysis exporter rounds; these pairs are the display contract.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatIntGrouped, formatSig, formatTimeCompact } from '../format.js';

const CASES = [
  [25129.282828282827, 25129],
  [100, 100],
  [0, 0],
  [1.5, 1.5],
  [5.4512612868893595e-34, 5.451e-34],
];

test('display rounding does not change table or tooltip text', () => {
  for (const [original, published] of CASES) {
    assert.equal(formatIntGrouped(original), formatIntGrouped(published), String(original));
    assert.equal(formatSig(original), formatSig(published), String(original));
    assert.equal(formatSig(original / 1e3), formatSig(published / 1e3), String(original));
    assert.equal(formatSig(original / 1e6), formatSig(published / 1e6), String(original));
    assert.equal(formatTimeCompact(original), formatTimeCompact(published), String(original));
  }
});
