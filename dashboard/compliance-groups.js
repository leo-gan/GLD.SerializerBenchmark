/**
 * Compliance Standard dropdown grouping.
 *
 * Membership is many-to-many: one serializer may belong to several
 * Standard families (JSON and YAML, JSON and MessagePack, …).
 *
 * All            = bench roster ∪ every scored name (one row per serializer).
 * Standard S     = serializers listed under S in
 *                  compliance/serializer-standards.json (same file the
 *                  runners use), plus any that have live matrix cells for S.
 *                  Subsets may overlap; a multi-standard name is in each.
 * * No public spec = All − ∪(every Standard). Classification, not “has a
 *                  live catalog run”, decides membership — mpack is
 *                  MessagePack even with empty cells.
 */
import {
  languageOf,
  matchesRow,
  parseRowIdentity,
  rowIdentity,
  serializerOf,
} from './compliance-matrix.js';
import { classifySerializer } from './compliance-classify.js';

export const ALL_FORMAT = '';
export const NO_SPEC = 'no-spec';
export const NO_SPEC_LABEL = '* No public spec';
/** Disabled <option> between populated Standards and those with no serializers. */
export const EMPTY_STANDARDS_SEP = '── no serializers ──';
export const EMPTY_STANDARDS_SEP_ID = '__no-serializers__';

/** Compliance adapter names that must match the Overview / bench display name. */
export const SERIALIZER_ALIASES = {
  csharp: { 'protobuf-net': 'ProtoBuf' },
  javascript: { 'JSON.parse': 'JSON.stringify' },
  python: { fastavro: 'avro' },
  swift: {
    'Foundation.JSONSerialization': 'Foundation.JSONEncoder',
    'Foundation.PropertyListSerialization': 'Foundation.PropertyListEncoder',
  },
  mojo: { 'mojo-yaml': 'gld-yaml' },
};

export const FORMAT_LABELS = {
  json: 'JSON',
  yaml: 'YAML',
  toml: 'TOML',
  cbor: 'CBOR',
  msgpack: 'MessagePack',
  protobuf: 'Protocol Buffers',
  avro: 'Avro',
  bson: 'BSON',
  flatbuffers: 'FlatBuffers',
  ion: 'Amazon Ion',
  ubjson: 'UBJSON',
  smile: 'Smile',
  thrift: 'Thrift',
  capnp: "Cap'n Proto",
  bond: 'Bond',
  bebop: 'Bebop',
  hocon: 'HOCON',
  plist: 'Property List',
  zon: 'ZON',
  [NO_SPEC]: NO_SPEC_LABEL,
};

export function formatLabel(id) {
  if (id === NO_SPEC) return NO_SPEC_LABEL;
  return FORMAT_LABELS[id] || id;
}

export function canonicalSerializer(language, name) {
  const raw = String(name || '');
  if (!raw) return '';
  return SERIALIZER_ALIASES[language]?.[raw] || raw;
}

export function normalizeEntry(row, fallbackLang = '') {
  const language = languageOf(row, fallbackLang);
  const serializer = canonicalSerializer(language, serializerOf(row));
  return {
    language,
    serializer,
    key: rowIdentity({ language, serializer }),
  };
}

export function normalizeMatrixCell(cell, fallbackLang = '') {
  if (!cell || typeof cell !== 'object') return cell;
  const { language, serializer } = normalizeEntry(cell, fallbackLang);
  if (language === languageOf(cell, fallbackLang) && serializer === serializerOf(cell)) {
    return cell;
  }
  return { ...cell, language, serializer };
}

export function scoredFormatIds() {
  return Object.keys(FORMAT_LABELS)
    .filter((id) => id !== NO_SPEC)
    .sort((a, b) => formatLabel(a).localeCompare(formatLabel(b), undefined, { sensitivity: 'base' }));
}

/** Standard <option> values after the implicit All (flat, no separator). */
export function standardOptionIds() {
  return [...scoredFormatIds(), NO_SPEC];
}

/** True when this language's roster has at least one serializer in the family. */
export function standardHasSerializers(format, { language = '', benchVersions = {}, matrix = [] } = {}) {
  return formatSubset(matrix, format, language, benchVersions).length > 0;
}

/**
 * Standard dropdown items after All:
 *   populated families (sorted) → * No public spec → disabled separator → empty families (sorted).
 */
export function standardMenuOptions({ language = '', benchVersions = {}, matrix = [] } = {}) {
  const populated = [];
  const empty = [];
  for (const id of scoredFormatIds()) {
    if (standardHasSerializers(id, { language, benchVersions, matrix })) populated.push(id);
    else empty.push(id);
  }
  const items = [
    ...populated.map((id) => ({ id, disabled: false })),
    { id: NO_SPEC, disabled: false },
  ];
  if (empty.length) {
    items.push({ id: EMPTY_STANDARDS_SEP_ID, label: EMPTY_STANDARDS_SEP, disabled: true });
    for (const id of empty) items.push({ id, disabled: false });
  }
  return items;
}

function pushUnique(out, seen, entry) {
  if (!entry.serializer) return;
  if (seen.has(entry.key)) return;
  seen.add(entry.key);
  out.push(entry);
}

export function entriesFromMatrix(matrix, language = '') {
  const out = [];
  const seen = new Set();
  for (const cell of Array.isArray(matrix) ? matrix : []) {
    const entry = normalizeEntry(cell);
    if (language && language !== 'all' && entry.language !== language) continue;
    pushUnique(out, seen, entry);
  }
  return out;
}

/** Latest-stats groups → { serializer name → version or '' }. Empty versions stay on the roster. */
export function benchMapFromGroups(groups) {
  const map = {};
  for (const g of groups || []) {
    const name = g?.serializer;
    if (!name || map[name] !== undefined) continue;
    const ver = g?.serializer_version;
    map[name] = ver ? String(ver) : '';
  }
  return map;
}

export function entriesFromBenchMap(benchVersions, language = '') {
  const out = [];
  const seen = new Set();
  const langs =
    language && language !== 'all'
      ? [language]
      : Object.keys(benchVersions || {});
  for (const lang of langs) {
    const names = benchVersions?.[lang];
    const list = Array.isArray(names) ? names : Object.keys(names || {});
    for (const name of list) {
      pushUnique(out, seen, normalizeEntry({ language: lang, serializer: name }));
    }
  }
  return out;
}

/**
 * All-serializers set for a language (or every language when language is
 * empty / 'all'): Overview bench names plus any scored compliance name.
 */
export function rosterEntries({ language = '', benchVersions = {}, matrix = [] } = {}) {
  const out = [];
  const seen = new Set();
  for (const entry of [
    ...entriesFromBenchMap(benchVersions, language),
    ...entriesFromMatrix(matrix, language),
  ]) {
    pushUnique(out, seen, entry);
  }
  out.sort((a, b) => {
    const lang = String(a.language).localeCompare(String(b.language));
    if (lang) return lang;
    return String(a.serializer).localeCompare(String(b.serializer));
  });
  return out;
}

function addFormats(map, entry, formats) {
  if (!entry?.key || !formats?.length) return;
  if (!map.has(entry.key)) map.set(entry.key, new Set());
  const set = map.get(entry.key);
  for (const fmt of formats) {
    if (fmt && fmt !== NO_SPEC) set.add(fmt);
  }
}

/**
 * serializer key → set of format families (classification ∪ live cells).
 * A key with size > 1 is a multi-standard serializer.
 */
export function formatsBySerializer(matrix, language = '', benchVersions = {}) {
  const map = new Map();
  for (const cell of Array.isArray(matrix) ? matrix : []) {
    const fmt = String(cell.format || '');
    if (!fmt || fmt === NO_SPEC) continue;
    const entry = normalizeEntry(cell);
    if (language && language !== 'all' && entry.language !== language) continue;
    addFormats(map, entry, [fmt]);
  }
  for (const entry of [
    ...entriesFromBenchMap(benchVersions, language),
    ...entriesFromMatrix(matrix, language),
  ]) {
    addFormats(map, entry, classifySerializer(entry.language, entry.serializer));
  }
  return map;
}

export function formatListForKey(matrix, key, language = '') {
  const set = formatsBySerializer(matrix, language).get(key);
  return set ? [...set].sort() : [];
}

/** Serializers that belong to a Standard (classified or live cells). Overlaps allowed. */
export function formatSubset(matrix, format, language = '', benchVersions = {}) {
  const out = [];
  const seen = new Set();
  if (!format || format === NO_SPEC) return out;
  for (const cell of Array.isArray(matrix) ? matrix : []) {
    if (String(cell.format || '') !== format) continue;
    const entry = normalizeEntry(cell);
    if (language && language !== 'all' && entry.language !== language) continue;
    pushUnique(out, seen, entry);
  }
  for (const entry of [
    ...entriesFromBenchMap(benchVersions, language),
    ...entriesFromMatrix(matrix, language),
  ]) {
    if (classifySerializer(entry.language, entry.serializer).includes(format)) {
      pushUnique(out, seen, entry);
    }
  }
  out.sort((a, b) => {
    const lang = String(a.language).localeCompare(String(b.language));
    if (lang) return lang;
    return String(a.serializer).localeCompare(String(b.serializer));
  });
  return out;
}

export function scoredEntries(matrix, language = '', benchVersions = {}) {
  const out = [];
  const seen = new Set();
  const membership = formatsBySerializer(matrix, language, benchVersions);
  for (const entry of rosterEntries({ language, benchVersions, matrix })) {
    if (membership.get(entry.key)?.size) pushUnique(out, seen, entry);
  }
  return out;
}

/** All − ∪(every Standard). Multi-standard names are in the union once. */
export function noSpecEntries({ language = '', benchVersions = {}, matrix = [] } = {}) {
  const scored = new Set(scoredEntries(matrix, language, benchVersions).map((e) => e.key));
  return rosterEntries({ language, benchVersions, matrix }).filter((e) => !scored.has(e.key));
}

export function padHeatmap(heat, extras, { serializerKey = '' } = {}) {
  const rowMap = new Map((heat?.rows || []).map((row) => [row.key, row]));
  for (const extra of extras || []) {
    const entry = normalizeEntry(extra);
    if (!entry.serializer) continue;
    if (serializerKey && !matchesRow({ language: entry.language, serializer: entry.serializer }, serializerKey)) {
      continue;
    }
    if (rowMap.has(entry.key)) continue;
    rowMap.set(entry.key, {
      key: entry.key,
      language: entry.language,
      serializer: entry.serializer,
      sample: { language: entry.language, serializer: entry.serializer },
      byStandard: new Map(),
    });
  }
  const rows = [...rowMap.values()].sort((a, b) => {
    const lang = String(a.language).localeCompare(String(b.language));
    if (lang) return lang;
    return String(a.serializer).localeCompare(String(b.serializer));
  });
  return { columns: heat?.columns || [], rows, filtered: heat?.filtered || [] };
}

/** Copy each row's format families onto `row.formats` (sorted). */
export function attachFormats(heat, matrix, language = '', benchVersions = {}) {
  const byKey = formatsBySerializer(matrix, language, benchVersions);
  const rows = (heat?.rows || []).map((row) => ({
    ...row,
    formats: [...(byKey.get(row.key) || [])].sort((a, b) =>
      formatLabel(a).localeCompare(formatLabel(b), undefined, { sensitivity: 'base' }),
    ),
  }));
  return { columns: heat?.columns || [], rows, filtered: heat?.filtered || [] };
}

export function rowIsUnscored(row) {
  if (!row?.byStandard || row.byStandard.size === 0) return true;
  for (const acc of row.byStandard.values()) {
    if ((Number(acc?.total) || 0) > 0) return false;
  }
  return true;
}

/**
 * Invariants for the Standard dropdown subsets.
 *
 * All = ∪(Standard options) ∪ No public spec, disjoint between those two
 * sides. Standard options themselves may overlap.
 * Returns { all, scored, noSpec, membership, issues }.
 */
export function auditComplianceGroups({ language = '', benchVersions = {}, matrix = [] } = {}) {
  const all = rosterEntries({ language, benchVersions, matrix });
  const scored = scoredEntries(matrix, language, benchVersions);
  const noSpec = noSpecEntries({ language, benchVersions, matrix });
  const membership = formatsBySerializer(matrix, language, benchVersions);
  const allKeys = new Set(all.map((e) => e.key));
  const scoredKeys = new Set(scored.map((e) => e.key));
  const noSpecKeys = new Set(noSpec.map((e) => e.key));
  const issues = [];

  const menu = standardMenuOptions({ language, benchVersions, matrix });
  const noSpecAt = menu.findIndex((item) => item.id === NO_SPEC);
  const sepAt = menu.findIndex((item) => item.id === EMPTY_STANDARDS_SEP_ID);
  if (noSpecAt < 0) {
    issues.push('No public spec is missing from the Standard dropdown');
  } else if (sepAt >= 0 && noSpecAt > sepAt) {
    issues.push('No public spec should sit above the empty-standards separator');
  }
  if (sepAt >= 0 && !menu[sepAt].disabled) {
    issues.push('empty-standards separator must be disabled');
  }
  if (formatLabel(NO_SPEC) !== NO_SPEC_LABEL || !NO_SPEC_LABEL.startsWith('*')) {
    issues.push(`No public spec label should be ${JSON.stringify(NO_SPEC_LABEL)}`);
  }

  for (const e of scored) {
    if (!allKeys.has(e.key)) {
      issues.push(`scored serializer missing from All: ${e.language}/${e.serializer}`);
    }
    if (noSpecKeys.has(e.key)) {
      issues.push(`serializer in both a Standard and No public spec: ${e.language}/${e.serializer}`);
    }
  }
  for (const e of noSpec) {
    if (!allKeys.has(e.key)) {
      issues.push(`No public spec serializer missing from All: ${e.language}/${e.serializer}`);
    }
    if (scoredKeys.has(e.key)) {
      issues.push(`serializer in both a Standard and No public spec: ${e.language}/${e.serializer}`);
    }
  }
  for (const e of all) {
    const inS = scoredKeys.has(e.key);
    const inN = noSpecKeys.has(e.key);
    if (inS === inN) {
      issues.push(`All serializer not partitioned: ${e.language}/${e.serializer}`);
    }
  }
  // Union cardinality, not a sum of option sizes (those may overlap).
  if (all.length !== scored.length + noSpec.length) {
    issues.push(
      `All (${all.length}) !== scored-union (${scored.length}) + No public spec (${noSpec.length})`,
    );
  }

  const union = new Set();
  let subsetSum = 0;
  for (const fmt of scoredFormatIds()) {
    const subset = formatSubset(matrix, fmt, language, benchVersions);
    subsetSum += subset.length;
    for (const e of subset) union.add(e.key);
  }
  if (subsetSum < union.size) {
    issues.push(`sum of Standard subset sizes (${subsetSum}) < union (${union.size})`);
  }
  for (const key of scoredKeys) {
    if (!union.has(key)) {
      const { language: lang, serializer } = parseRowIdentity(key);
      issues.push(`scored serializer not in any Standard subset: ${lang}/${serializer}`);
    }
  }
  for (const key of union) {
    if (!scoredKeys.has(key)) {
      const { language: lang, serializer } = parseRowIdentity(key);
      issues.push(`Standard subset member missing from scored union: ${lang}/${serializer}`);
    }
  }

  for (const [key, fmts] of membership) {
    if (noSpecKeys.has(key)) {
      const { language: lang, serializer } = parseRowIdentity(key);
      issues.push(`multi-standard candidate also in No public spec: ${lang}/${serializer}`);
    }
    if (!allKeys.has(key)) {
      const { language: lang, serializer } = parseRowIdentity(key);
      issues.push(`membership key missing from All: ${lang}/${serializer}`);
    }
    for (const fmt of fmts) {
      const hit = formatSubset(matrix, fmt, language, benchVersions).some((e) => e.key === key);
      if (!hit) {
        const { language: lang, serializer } = parseRowIdentity(key);
        issues.push(`${lang}/${serializer} has ${fmt} cells but is missing from that Standard subset`);
      }
    }
  }

  return { all, scored, noSpec, membership, issues };
}
