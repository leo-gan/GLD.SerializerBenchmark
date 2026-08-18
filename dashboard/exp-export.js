/**
 * Experiment table export — CSV download, TSV clipboard, shared row helpers.
 * Do not import main.js.
 */
import { formatSig } from './format.js';

const COMPARE_LABEL = {
  fastest: 'Fastest',
  reference: 'Fastest',
  similar: 'About the same',
  close: 'A bit slower',
  slower: 'Clearly slower',
};

export const ALL_LANG = 'all';

const CSV_COLUMNS = [
  'library',
  'version',
  'io',
  'write_us',
  'read_us',
  'total_us',
  'spread_std_us',
  'size_bytes',
  'size_gzip_bytes',
  'trials',
  'trials_raw',
  'vs_fastest',
  'in_comparison',
];

export function isAllLang(lang) {
  return lang === ALL_LANG;
}

/** True when the current rows cover more than one tagged language. */
export function mixedLanguages(rows) {
  const langs = new Set();
  for (const row of rows || []) {
    if (row?.language == null || row.language === '') continue;
    langs.add(String(row.language));
    if (langs.size > 1) return true;
  }
  return false;
}

/**
 * Rows that share this row’s language. Untagged lists stay one contest.
 * Used so All-tab colors and “vs fastest” never rank Rust against Java.
 */
export function peerRows(row, rows) {
  const list = rows || [];
  const lang = row?.language;
  if (lang == null || lang === '') return list;
  const peers = list.filter((r) => r.language === lang);
  return peers.length ? peers : list;
}

/** Flatten ok language blocks, tagging every row with `language`. */
export function flattenLanguageRows(languages, langIds) {
  const rows = [];
  for (const id of langIds || []) {
    const block = languages?.[id];
    if (!block || (block.status && block.status !== 'ok')) continue;
    for (const row of block.rows || []) {
      rows.push({ ...row, language: id });
    }
  }
  return rows;
}

/** True skip: different JSON shape. Stream rows are not skips — they are a different filter. */
export function isShapeSkip(row) {
  return row?.writes_named_fields === false;
}

/** Rows that compete in the current view (named JSON; stream if that is all we have). */
export function competingRows(rows) {
  const named = (rows || []).filter((r) => !isShapeSkip(r));
  const official = named.filter((r) => r.in_comparison !== false);
  return official.length ? official : named;
}

const TIER_RANK = { fastest: 0, similar: 1, close: 2, slower: 3 };

function milderTier(a, b) {
  if (!a) return b || '';
  if (!b) return a;
  return TIER_RANK[a] <= TIER_RANK[b] ? a : b;
}

function tierFromMedianRatio(row, rows) {
  const pool = competingRows(rows);
  const best = Math.min(...pool.map((r) => Number(r.total_median_ns)).filter(Number.isFinite));
  const v = Number(row.total_median_ns);
  if (!Number.isFinite(v) || !Number.isFinite(best) || best <= 0) return '';
  if (v <= best) return 'fastest';
  const ratio = v / best;
  if (ratio <= 1.15) return 'similar';
  if (ratio <= 1.5) return 'close';
  return 'slower';
}

/**
 * Color / chip tier for the current filter.
 *
 * Cliff's delta (published `tier`) asks “how often is this slower?”, not
 * “how big is the gap?”. A 2% median gap can still be “slower” if it is
 * consistent. Students see bar length, so we never paint “clearly slower”
 * when the medians are about the same: take the milder of Cliffs and the
 * median-ratio band (≤1.15× similar, ≤1.5× close).
 */
export function displayTier(row, rows) {
  const peers = peerRows(row, rows);
  if (isShapeSkip(row)) return 'skip';
  if (row.tier === 'fastest' || row.cliffs_label === 'reference') return 'fastest';
  const fromRatio = tierFromMedianRatio(row, peers);
  if (fromRatio === 'fastest') return 'fastest';
  const fromCliffs =
    row.tier === 'similar' || row.tier === 'close' || row.tier === 'slower' ? row.tier : '';
  return milderTier(fromCliffs, fromRatio) || fromRatio;
}

/**
 * Why a timed row is drawn but not ranked.
 * Only the different-JSON-shape case. Stream is a filter, not a skip.
 */
export function skipReason(row) {
  if (!isShapeSkip(row)) return null;
  return {
    short: 'writes […] on purpose',
    label: 'By design — JSON list',
    chip: row.library || 'library',
    detail:
      'By design, not a failed read. This bench uses msgspec array-like Structs: write emits a JSON list [1, "ok", …] and read loads that same list back by field order. Both steps succeed. orjson/json write {"id": 1, "status": "ok"}. This experiment ranks only that named object, so we show the time but do not pick a winner against the list.',
  };
}

export function compareLabel(row, rows) {
  const skip = skipReason(row);
  if (skip) return skip.label;
  const key = displayTier(row, rows || [row]);
  return COMPARE_LABEL[key] || COMPARE_LABEL[row.cliffs_label] || '—';
}

/** Sample std in µs, or reconstructed from the published mean CI. */
export function totalStdUs(row) {
  let ns = row.total_std_ns;
  if (ns == null) {
    const lo = Number(row.total_ci_low_ns);
    const hi = Number(row.total_ci_high_ns);
    const n = Number(row.runs);
    if (!Number.isFinite(lo) || !Number.isFinite(hi) || !n || n < 2) return null;
    ns = ((hi - lo) / (2 * 1.96)) * Math.sqrt(n);
  }
  if (!Number.isFinite(Number(ns))) return null;
  return Number(ns) / 1000;
}

export function sortRows(rows) {
  return [...rows].sort((a, b) => {
    const as = isShapeSkip(a) ? 1 : 0;
    const bs = isShapeSkip(b) ? 1 : 0;
    if (as !== bs) return as - bs;
    return (Number(a.total_median_ns) || 1e18) - (Number(b.total_median_ns) || 1e18);
  });
}

export function exportStem({ id, lang, io, extra } = {}) {
  return [id, lang, io, extra].filter((t) => t != null && String(t) !== '').join('-');
}

function nsToUs(ns) {
  const n = Number(ns);
  return Number.isFinite(n) ? n / 1000 : '';
}

function escapeField(value, delimiter) {
  if (value == null) return '';
  const s = typeof value === 'boolean' ? String(value) : String(value);
  if (s.includes('"') || s.includes(delimiter) || s.includes('\n') || s.includes('\r')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function rowHasLanguage(rows) {
  return (rows || []).some((r) => r?.language != null && r.language !== '');
}

function csvColumns(rows) {
  return rowHasLanguage(rows) ? ['language', ...CSV_COLUMNS] : CSV_COLUMNS;
}

function rowFields(row, rows) {
  const std = totalStdUs(row);
  return {
    language: row.language ?? '',
    library: row.library ?? '',
    version: row.version ?? '',
    io: row.io ?? '',
    write_us: nsToUs(row.write_median_ns),
    read_us: nsToUs(row.read_median_ns),
    total_us: nsToUs(row.total_median_ns),
    spread_std_us: std == null ? '' : std,
    size_bytes: row.size_bytes == null ? '' : row.size_bytes,
    size_gzip_bytes: row.size_gzip_bytes == null ? '' : row.size_gzip_bytes,
    trials: row.runs == null ? '' : row.runs,
    trials_raw: row.runs_raw == null ? '' : row.runs_raw,
    vs_fastest: compareLabel(row, rows),
    in_comparison: row.in_comparison === false ? false : true,
  };
}

export function rowsToDelimited(rows, { delimiter = ',' } = {}) {
  const sorted = sortRows(rows);
  const cols = csvColumns(sorted);
  const lines = [cols.join(delimiter)];
  for (const row of sorted) {
    const fields = rowFields(row, sorted);
    lines.push(cols.map((k) => escapeField(fields[k], delimiter)).join(delimiter));
  }
  return `${lines.join('\n')}\n`;
}

export function downloadText(filename, text, mime = 'text/csv;charset=utf-8') {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export function downloadDataUrl(dataUrl, filename) {
  const a = document.createElement('a');
  a.href = dataUrl;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

export async function copyText(text) {
  if (!navigator.clipboard?.writeText) {
    throw new Error('Clipboard unavailable');
  }
  await navigator.clipboard.writeText(text);
}

