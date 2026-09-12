/**
 * Standard membership from compliance/serializer-standards.json.
 * That file is the source of truth for the dashboard and every runner.
 * Do not infer a family from the serializer's spelling.
 */
import mapping from '../compliance/serializer-standards.json' with { type: 'json' };
import { CATALOG_BY_KEY } from './compliance-catalog.js';

export function catalogKey(language, name) {
  return `${language}\0${name}`;
}

export function catalogEntry(language, name) {
  return CATALOG_BY_KEY.get(catalogKey(language, name)) || null;
}

function languageSlice(language) {
  const langs = mapping?.languages;
  if (!langs || typeof langs !== 'object') return null;
  const slice = langs[language];
  return slice && typeof slice === 'object' ? slice : null;
}

/** Documented format families for this registered row. Empty = no public spec. */
export function classifySerializer(language, name) {
  const slice = languageSlice(language);
  if (!slice || !Object.prototype.hasOwnProperty.call(slice, name)) return [];
  const fmts = slice[name];
  return Array.isArray(fmts) ? [...fmts] : [];
}

/** Language-less lookup only when every language agrees on the same formats. */
export function classifyByName(name) {
  const langs = mapping?.languages || {};
  const hits = [];
  for (const slice of Object.values(langs)) {
    if (slice && Object.prototype.hasOwnProperty.call(slice, name)) {
      hits.push(Array.isArray(slice[name]) ? slice[name] : []);
    }
  }
  if (!hits.length) return [];
  const first = hits[0].join('\0');
  if (hits.every((fmts) => fmts.join('\0') === first)) return [...hits[0]];
  return [];
}

export function catalogMissing(language, name) {
  const slice = languageSlice(language);
  return !slice || !Object.prototype.hasOwnProperty.call(slice, name);
}
