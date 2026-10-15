/**
 * Compare-table selection: one list of {lang, serializer}.
 * A single language and a mix of languages are the same list.
 * Pure helpers so URL migration and filter hiding can be tested without the DOM.
 */

export const MAX_COMPARE_COLUMNS = 8;

const ALL_LANG = 'all';

/** @param {{ lang?: string, serializer?: string } | null | undefined} pick */
export function pickKey(pick) {
  if (!pick || !pick.lang || !pick.serializer) return '';
  return `${pick.lang}|${pick.serializer}`;
}

/**
 * `lang|serializer`, or a bare serializer name.
 * A bare name uses fallbackLang, except when that fallback is ALL.
 * @param {string} token
 * @param {string} [fallbackLang]
 */
export function parseSerToken(token, fallbackLang) {
  const raw = String(token || '').trim();
  if (!raw) return null;
  const bar = raw.indexOf('|');
  if (bar > 0 && bar < raw.length - 1) {
    return { lang: raw.slice(0, bar).trim(), serializer: raw.slice(bar + 1).trim() };
  }
  const lang = fallbackLang && fallbackLang !== ALL_LANG ? fallbackLang : '';
  return { lang, serializer: raw };
}

/** Drop blanks and duplicates. Keep the first of each pair, capped at 8. */
export function dedupePicks(picks, max = MAX_COMPARE_COLUMNS) {
  const out = [];
  const seen = new Set();
  for (const pick of picks || []) {
    if (!pick || typeof pick.serializer !== 'string') continue;
    const serializer = pick.serializer.trim();
    if (!serializer) continue;
    const lang = typeof pick.lang === 'string' ? pick.lang.trim() : '';
    const key = lang ? `${lang}|${serializer}` : `\0|${serializer}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ lang, serializer });
    if (out.length >= max) break;
  }
  return out;
}

/**
 * @param {string} token
 * @param {{ lang: string, serializer: string }[]} picks
 * @param {string} [fallbackLang]
 */
export function baselineFromToken(picks, token, fallbackLang) {
  const parsed = parseSerToken(token, fallbackLang);
  if (!parsed) return '';
  if (parsed.lang) {
    const exact = (picks || []).find(
      (p) => p.lang === parsed.lang && p.serializer === parsed.serializer,
    );
    if (exact) return pickKey(exact);
  }
  const byName = (picks || []).filter((p) => p.serializer === parsed.serializer && p.lang);
  if (byName.length === 1) return pickKey(byName[0]);
  return '';
}

/** Keep a baseline that still names a pick. Otherwise the first pick. */
export function ensureBaseline(picks, baselineKey) {
  const list = picks || [];
  if (baselineKey && list.some((p) => pickKey(p) === baselineKey)) return baselineKey;
  const rebound = baselineFromToken(list, baselineKey, '');
  if (rebound) return rebound;
  return pickKey(list[0]);
}

/**
 * One list from a saved dashboard and the URL.
 *
 * `ser` on the URL wins, except an old `scope=cross` link: that table lived in
 * `xlSelected`, and `ser` was the other list. A saved `comparePicks` array,
 * including an empty one, is the new list and is not replaced by legacy fields.
 *
 * @returns {{ picks: {lang: string, serializer: string}[], baseline: string, set: boolean }}
 */
export function migrateCompareSelection(input = {}) {
  const currentLanguage = input.currentLanguage || '';
  const urlSers = Array.isArray(input.urlSers) ? input.urlSers.filter(Boolean) : [];
  const scope = input.urlScope || input.scope || '';
  const xlSelected = Array.isArray(input.xlSelected) ? input.xlSelected : [];
  const detailSerializers = Array.isArray(input.detailSerializers) ? input.detailSerializers : [];
  const comparePicksPresent = input.comparePicksPresent === true;

  let source = '';
  /** @type {{ lang: string, serializer: string }[]} */
  let picks = [];

  if (urlSers.length && scope !== 'cross') {
    source = 'url';
    picks = dedupePicks(urlSers.map((token) => parseSerToken(token, currentLanguage)));
  } else if (scope === 'cross' && xlSelected.length && !comparePicksPresent) {
    source = 'cross';
    picks = dedupePicks(xlSelected);
  } else if (urlSers.length) {
    source = 'url';
    picks = dedupePicks(urlSers.map((token) => parseSerToken(token, currentLanguage)));
  } else if (comparePicksPresent) {
    source = 'saved';
    picks = dedupePicks(input.comparePicks);
  } else if (detailSerializers.length) {
    source = 'detail';
    picks = dedupePicks(detailSerializers.map((token) => parseSerToken(token, currentLanguage)));
  }

  const set = source !== '';
  let tokens = [];
  if (source === 'cross') tokens = [input.urlCbase, input.xlBaselineKey, input.urlBaseline];
  else if (source === 'saved') tokens = [input.urlCbase, input.comparePickBaseline];
  else if (source === 'url' || source === 'detail') {
    tokens = [input.urlCbase, input.urlBaseline, input.compareBaseline];
  }

  let baseline = '';
  if (set) {
    for (const token of tokens) {
      baseline = baselineFromToken(picks, token, currentLanguage);
      if (baseline) break;
    }
    if (!baseline) baseline = pickKey(picks[0]);
  }
  return { picks, baseline, set };
}

/**
 * Fill a blank language once groups are loaded.
 * One language page: the name belongs to that language even with no row yet.
 * ALL: a single matching group decides. Several matches stay blank so the
 * chip is hidden instead of attached to the wrong language.
 */
export function resolvePickLanguage(pick, groups, currentLanguage) {
  if (!pick || !pick.serializer) return null;
  const serializer = String(pick.serializer).trim();
  if (!serializer) return null;
  if (pick.lang) return { lang: String(pick.lang).trim(), serializer };
  const matches = (groups || []).filter((g) => g && g.serializer === serializer && g.language);
  if (currentLanguage && currentLanguage !== ALL_LANG) {
    return { lang: currentLanguage, serializer };
  }
  if (matches.length === 1) return { lang: matches[0].language, serializer };
  return { lang: '', serializer };
}

export function resolvePickLanguages(picks, groups, currentLanguage) {
  return dedupePicks(
    (picks || [])
      .map((pick) => resolvePickLanguage(pick, groups, currentLanguage))
      .filter(Boolean),
  );
}

/** Picks that have a measured row in the current filter. Order is unchanged. */
export function visiblePicks(picks, groups) {
  const have = new Set(
    (groups || [])
      .filter((g) => g && g.language && g.serializer)
      .map((g) => `${g.language}|${g.serializer}`),
  );
  return (picks || []).filter((pick) => pick && have.has(pickKey(pick)));
}

export function hiddenPickCount(picks, groups) {
  const visible = visiblePicks(picks, groups);
  return Math.max(0, (picks || []).filter((pick) => pick && pick.serializer).length - visible.length);
}

/** Baseline chip if it is visible, otherwise the first visible chip. */
export function effectiveBaseline(visible, baselineKey) {
  if (!visible || !visible.length) return null;
  return visible.find((pick) => pickKey(pick) === baselineKey) || visible[0];
}

/**
 * Table order: the effective baseline, then the other visible picks in chip order.
 */
export function orderedVisible(picks, groups, baselineKey) {
  const visible = visiblePicks(picks, groups);
  const base = effectiveBaseline(visible, baselineKey);
  if (!base) return [];
  const baseId = pickKey(base);
  return [base, ...visible.filter((pick) => pickKey(pick) !== baseId)];
}

/** First-visit seed. `groups` is already in the order to keep. */
export function seedPicks(groups, max = 6) {
  const picks = dedupePicks(
    (groups || [])
      .filter((g) => g && g.language && g.serializer)
      .map((g) => ({ lang: g.language, serializer: g.serializer })),
    max,
  );
  return { picks, baseline: pickKey(picks[0]), set: picks.length > 0 };
}
