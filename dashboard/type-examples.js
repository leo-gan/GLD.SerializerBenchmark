/**
 * Which n=1 examples to show for the current Data Type menu value.
 * A batch, a compound, or an all@ row still shows one record.
 */
import { SUITE_TYPE_IDS, baseTypeId } from './fixture-types.js';
import { escapeHtml } from './page.js';

export function exampleTypeIds(key) {
  const s = String(key || '').trim();
  if (!s) return [];
  if (s === 'all@all' || /^all@/i.test(s)) return [...SUITE_TYPE_IDS];
  const base = baseTypeId(s);
  return base ? [base] : [];
}

/** True when the menu is one data type at one record, not a batch or an average. */
export function exampleIsSingleRecord(key) {
  const s = String(key || '').trim();
  if (!s || s === 'all@all' || /^all@/i.test(s) || s.includes('+')) return false;
  const match = s.match(/@n=(\d+)$/i);
  if (!match) return !s.includes('@');
  return match[1] === '1';
}

export function exampleSummary(count) {
  return count > 1
    ? 'Examples · one record each (n=1)'
    : 'Example · one record (n=1)';
}

/**
 * Body of the folded example. The caller owns the <details> and leaves it closed.
 * @param {{ ids: string[], examples: { types?: Record<string, { note?: string, record?: unknown }> }, menuLabel?: string, singleRecord?: boolean }} args
 */
export function renderTypeExampleBody({ ids, examples, menuLabel = '', singleRecord = true }) {
  const types = examples?.types || {};
  const blocks = [];
  for (const id of ids) {
    const entry = types[id];
    if (!entry || entry.record == null) continue;
    const note = entry.note ? `<p class="datatype-example-note">${escapeHtml(entry.note)}</p>` : '';
    const heading = ids.length > 1
      ? `<p class="datatype-example-kind"><strong>${escapeHtml(id)}</strong></p>`
      : '';
    blocks.push(
      `${heading}${note}<pre class="datatype-example-pre">${escapeHtml(JSON.stringify(entry.record, null, 2))}</pre>`,
    );
  }
  if (!blocks.length) return '';
  const menu = String(menuLabel || '').trim();
  const scope = !singleRecord && menu
    ? `<p class="datatype-example-note">The menu is ${escapeHtml(menu)}. This box is still one record.</p>`
    : '';
  return `${scope}<p class="datatype-example-note">n=1 only. A batch of 100 writes this record, then the next ones from the same builder and seed.</p>${blocks.join('')}`;
}
