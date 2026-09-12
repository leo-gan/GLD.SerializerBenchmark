/**
 * Heatmap grouping for the Compliance view.
 *
 * Rows are always language + serializer. The All-languages tab used to
 * key by serializer name only, which merged C/C++/Swift/Zig protobuf-wire
 * into one 48/48 cell and hid the other languages.
 */

export const ROW_SEP = '\x1f';

export function serializerOf(row) {
  return String(row?.serializer || row?.adapter || '');
}

export function languageOf(row, fallback = '') {
  const lang = row?.language;
  if (lang != null && String(lang).trim() && String(lang) !== 'all') {
    return String(lang);
  }
  if (fallback && fallback !== 'all') return String(fallback);
  return '';
}

export function rowIdentity(row, fallbackLang = '') {
  return `${languageOf(row, fallbackLang)}${ROW_SEP}${serializerOf(row)}`;
}

export function parseRowIdentity(key) {
  const raw = String(key || '');
  const i = raw.indexOf(ROW_SEP);
  if (i >= 0) {
    return { language: raw.slice(0, i), serializer: raw.slice(i + ROW_SEP.length) };
  }
  const j = raw.indexOf('|');
  if (j > 0) return { language: raw.slice(0, j), serializer: raw.slice(j + 1) };
  return { language: '', serializer: raw };
}

export function matchesRow(row, key, fallbackLang = '') {
  const id = parseRowIdentity(key);
  if (serializerOf(row) !== id.serializer) return false;
  if (id.language && languageOf(row, fallbackLang) !== id.language) return false;
  return true;
}

export function heatmapFromMatrix(matrix, { format = '', serializerKey = '' } = {}) {
  const cells = Array.isArray(matrix) ? matrix : [];
  const filtered = cells.filter((cell) => {
    if (format && String(cell.format) !== format) return false;
    if (serializerKey && !matchesRow(cell, serializerKey)) return false;
    return true;
  });
  const columns = [];
  const seenCol = new Set();
  for (const cell of filtered) {
    const key = String(cell.standard || '');
    if (!key || seenCol.has(key)) continue;
    seenCol.add(key);
    columns.push({
      key,
      standard: cell.standard,
      version: cell.version,
      standard_url: cell.standard_url || '',
    });
  }
  const rowMap = new Map();
  for (const cell of filtered) {
    const key = rowIdentity(cell);
    if (!rowMap.has(key)) {
      rowMap.set(key, {
        key,
        language: languageOf(cell),
        serializer: serializerOf(cell),
        sample: cell,
        byStandard: new Map(),
      });
    }
    const row = rowMap.get(key);
    const std = String(cell.standard || '');
    const acc = row.byStandard.get(std) || { passed: 0, failed: 0, total: 0 };
    acc.passed += Number(cell.passed) || 0;
    acc.failed += Number(cell.failed) || 0;
    acc.total += Number(cell.total) || 0;
    row.byStandard.set(std, acc);
  }
  const rows = [...rowMap.values()].sort((a, b) => {
    const lang = String(a.language).localeCompare(String(b.language));
    if (lang) return lang;
    return String(a.serializer).localeCompare(String(b.serializer));
  });
  return { columns, rows, filtered };
}
