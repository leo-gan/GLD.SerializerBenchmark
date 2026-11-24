/**
 * Pure visual cell builders for Overview Detailed Analytics and Compare tables.
 *
 * - Baseline ratio cells: symmetric log2 diverging micro-bar (Proposal 1A).
 * - Latency distribution cells: Pin & Tail spread strip (Proposal 2A),
 *   replacing separate mean / std / p50 / p95 / p99 rows per timing phase.
 */
import { formatLatencyCell, formatSig } from './format.js';
import { escapeHtml } from './page.js';

/** Max ±doublings represented on the diverging baseline micro-bar (≈0.09×–11.3×). */
export const RATIO_BAR_MAX_LOG2 = 3.5;

/** Timing phases whose mean/std/p50/p95/p99 keys collapse into one spread visual. */
export const SPREAD_PHASES = [
  {
    key: 'total_spread_ns',
    prefix: 'total',
    label: 'Write + read',
    replaces: [
      'avg_time_total_ns',
      'total_mean_ns',
      'total_std_ns',
      'total_median_ns',
      'total_p50_ns',
      'total_p95_ns',
      'total_p99_ns',
    ],
  },
  {
    key: 'ser_spread_ns',
    prefix: 'ser',
    label: 'Write',
    replaces: [
      'avg_time_ser_ns',
      'ser_mean_ns',
      'ser_std_ns',
      'ser_median_ns',
      'ser_p50_ns',
      'ser_p95_ns',
      'ser_p99_ns',
    ],
  },
  {
    key: 'deser_spread_ns',
    prefix: 'deser',
    label: 'Read',
    replaces: [
      'avg_time_deser_ns',
      'deser_mean_ns',
      'deser_std_ns',
      'deser_median_ns',
      'deser_p50_ns',
      'deser_p95_ns',
      'deser_p99_ns',
    ],
  },
];

const SPREAD_BY_KEY = new Map(SPREAD_PHASES.map((p) => [p.key, p]));
const REPLACED_TO_SPREAD = new Map();
for (const phase of SPREAD_PHASES) {
  for (const rawKey of phase.replaces) {
    REPLACED_TO_SPREAD.set(rawKey, phase.key);
  }
}

export function isSpreadMetric(key) {
  return SPREAD_BY_KEY.has(key);
}

export function spreadPhaseSpec(key) {
  return SPREAD_BY_KEY.get(key) || null;
}

export function spreadLabel(key, latencyUnitHeader = '') {
  const spec = SPREAD_BY_KEY.get(key);
  if (!spec) return key;
  return latencyUnitHeader ? `${spec.label} (${latencyUnitHeader})` : spec.label;
}

/**
 * Replace raw mean/std/p50/p95/p99 keys with one synthetic `*_spread_ns` key
 * per timing phase that is actually present in `rawKeys`.
 */
export function normalizeAvailableMetrics(rawKeys) {
  const rawSet = new Set(rawKeys || []);
  const out = new Set();
  for (const k of rawSet) {
    if (REPLACED_TO_SPREAD.has(k)) {
      out.add(REPLACED_TO_SPREAD.get(k));
    } else {
      out.add(k);
    }
  }
  return [...out].sort();
}

/**
 * Migrate saved/legacy metric selections that referenced raw mean/std/p50/p95/p99
 * keys onto the replacement `*_spread_ns` keys, deduplicated and filtered by `available`.
 */
export function migrateSelectedMetrics(selected, available) {
  const availSet = available ? new Set(available) : null;
  const seen = new Set();
  const out = [];
  for (const raw of selected || []) {
    const mapped = REPLACED_TO_SPREAD.get(raw) || raw;
    if (seen.has(mapped)) continue;
    if (availSet && !availSet.has(mapped)) continue;
    seen.add(mapped);
    out.push(mapped);
  }
  return out;
}

function finiteNum(v) {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

/**
 * Extract distribution quantiles & moments (in ns) for a synthetic spread key.
 * Returns null if neither median nor mean is available.
 */
export function extractSpreadStats(group, spreadKey) {
  const spec = SPREAD_BY_KEY.get(spreadKey);
  if (!group || !spec) return null;
  const p = spec.prefix;

  const median = finiteNum(group[`${p}_median_ns`]) ?? finiteNum(group[`${p}_p50_ns`]);
  const mean = finiteNum(group[`avg_time_${p}_ns`]) ?? finiteNum(group[`${p}_mean_ns`]);
  const p50 = median ?? mean;
  if (p50 == null || p50 <= 0) return null;
  const effMean = mean ?? p50;

  const min = finiteNum(group[`${p}_min_ns`]);
  const p5 = finiteNum(group[`${p}_p5_ns`]) ?? min ?? Math.min(p50, effMean);
  const p25 = finiteNum(group[`${p}_p25_ns`]);
  const p75 = finiteNum(group[`${p}_p75_ns`]);
  const p95Raw = finiteNum(group[`${p}_p95_ns`]);
  const p99Raw = finiteNum(group[`${p}_p99_ns`]);
  const max = finiteNum(group[`${p}_max_ns`]);
  const p99 = p99Raw ?? max ?? p95Raw ?? Math.max(p50, effMean);
  const p95 = p95Raw ?? p99;
  const std = Math.max(0, finiteNum(group[`${p}_std_ns`]) ?? 0);

  return {
    min: min ?? p5,
    p5,
    p25,
    p50,
    mean: effMean,
    std,
    p75,
    p95,
    p99,
    max: max ?? p99,
  };
}

/** Collect raw latency numbers (ns) from spread columns so unit choice stays accurate. */
export function spreadLatencyValues(groups, selectedKeys) {
  const vals = [];
  for (const key of selectedKeys || []) {
    if (!isSpreadMetric(key)) continue;
    for (const g of groups || []) {
      const s = extractSpreadStats(g, key);
      if (!s) continue;
      vals.push(s.p50, s.mean, s.p95, s.p99);
    }
  }
  return vals;
}

/**
 * Proposal 1A: Log2 Diverging Micro-Bar cell for baseline comparisons.
 *
 * Direction uses magnitude (<1× extends left, >1× extends right) while color
 * encodes quality (green = better than baseline, red = worse than baseline).
 *
 * @returns {{ html: string, md: string, title: string, isVisual: boolean }}
 */
export function renderDivergingRatioHtml({
  valueText,
  ratio,
  higherIsBetter,
  isBaseline = false,
  ratioTag = '',
}) {
  const valEsc = escapeHtml(valueText);

  if (isBaseline) {
    const html =
      `<div class="ratio-cell">` +
        `<div class="ratio-cell-top">` +
          `<span class="ratio-val ratio-val-base">${valEsc}</span>` +
          `<span class="ratio-tag ratio-tag-base">base</span>` +
        `</div>` +
        `<svg class="ratio-bar-svg" width="144" height="10" viewBox="0 0 144 10" aria-hidden="true">` +
          `<line x1="7" y1="5" x2="137" y2="5" class="ratio-track"/>` +
          `<line x1="72" y1="1" x2="72" y2="9" class="ratio-axis-base"/>` +
          `<polygon points="72,1.5 75.5,5 72,8.5 68.5,5" class="ratio-base-diamond"/>` +
        `</svg>` +
      `</div>`;
    return {
      html,
      md: String(valueText),
      title: `${valueText} (baseline)`,
      isVisual: true,
    };
  }

  if (
    typeof ratio !== 'number' ||
    !Number.isFinite(ratio) ||
    ratio <= 0 ||
    (higherIsBetter !== true && higherIsBetter !== false)
  ) {
    return {
      html: `<span class="ratio-val">${valEsc}</span>`,
      md: String(valueText),
      title: String(valueText),
      isVisual: false,
    };
  }

  const tag = ratioTag ? `×${ratioTag}` : '×';
  const ratioShort = `${formatSig(ratio, 2)}×`;
  const mdText = `${valueText} (${formatSig(ratio, 2)}${tag})`;
  const isTie = Math.abs(ratio - 1) < 0.01;
  const isBetter = !isTie && (higherIsBetter ? ratio > 1 : ratio < 1);
  const stateCls = isTie ? 'is-neutral' : isBetter ? 'is-better' : 'is-worse';

  const signedLog = Math.log2(ratio);
  const clamped = Math.max(-RATIO_BAR_MAX_LOG2, Math.min(RATIO_BAR_MAX_LOG2, signedLog));
  const overflowLeft = signedLog < -RATIO_BAR_MAX_LOG2;
  const overflowRight = signedLog > RATIO_BAR_MAX_LOG2;

  const cx = 72;
  const half = 63;
  const len = isTie ? 0 : Math.max(2.5, (Math.abs(clamped) / RATIO_BAR_MAX_LOG2) * half);
  const barX = clamped >= 0 ? cx : cx - len;
  const endX = isTie ? cx : clamped >= 0 ? cx + len : cx - len;

  const barRect = len > 0
    ? `<rect x="${barX.toFixed(1)}" y="2.5" width="${len.toFixed(1)}" height="5" rx="1.5" class="ratio-fill ${stateCls}"/>`
    : '';
  const arrowL = overflowLeft
    ? `<polygon points="1,5 6,2 6,8" class="ratio-fill ${stateCls}"/>`
    : '';
  const arrowR = overflowRight
    ? `<polygon points="143,5 138,2 138,8" class="ratio-fill ${stateCls}"/>`
    : '';
  // Show serializer value marker (blue ◆) whenever it fits within the chart range.
  const valDiamond = !overflowLeft && !overflowRight
    ? `<polygon points="${endX.toFixed(1)},1.5 ${(endX + 3.5).toFixed(1)},5 ${endX.toFixed(1)},8.5 ${(endX - 3.5).toFixed(1)},5" class="ratio-val-diamond"/>`
    : '';

  const html =
    `<div class="ratio-cell">` +
      `<div class="ratio-cell-top">` +
        `<span class="ratio-val">${valEsc}</span>` +
        `<span class="ratio-tag ${stateCls}">${escapeHtml(ratioShort)}</span>` +
      `</div>` +
      `<svg class="ratio-bar-svg" width="144" height="10" viewBox="0 0 144 10" aria-hidden="true">` +
        `<line x1="7" y1="5" x2="137" y2="5" class="ratio-track"/>` +
        `${barRect}` +
        `<line x1="${cx}" y1="1" x2="${cx}" y2="9" class="ratio-axis"/>` +
        `${valDiamond}${arrowL}${arrowR}` +
      `</svg>` +
    `</div>`;

  return {
    html,
    md: mdText,
    title: mdText,
    isVisual: true,
  };
}

/**
 * Proposal 2A: Pin & Tail Strip for latency spread (mean, std, p50, p95, p99).
 * Uses local scale `[p5 → p99]` so distribution shape and outlier pull remain clear.
 *
 * @returns {{ html: string, md: string, tooltip: object }}
 */
export function renderSpreadCellHtml(
  stats,
  latencyScale,
  { phaseLabel = '', serializerLabel = '' } = {},
) {
  const unit = latencyScale?.header || 'µs';
  const fmt = (ns) => formatLatencyCell(ns, latencyScale);

  const W = 176;
  const x0 = 6;
  const x1 = W - 6;
  const trackY = 20;

  const lo = Math.min(stats.p5, stats.p50, stats.mean);
  const hi = Math.max(stats.p99, stats.p95, stats.p50, stats.mean);
  const span = hi - lo;
  const px = (v) => {
    if (span <= 0) return (x0 + x1) / 2;
    const t = Math.max(0, Math.min(1, (v - lo) / span));
    return x0 + t * (x1 - x0);
  };

  const pullRatio = stats.p50 > 0 ? stats.mean / stats.p50 : 1;
  const pullPct = (pullRatio - 1) * 100;
  const skewCls = pullRatio >= 1.25 ? 'is-high-skew' : pullRatio >= 1.12 ? 'is-mid-skew' : 'is-calm';
  const showMeanLabel = pullRatio >= 1.12;

  const xMed = px(stats.p50);
  const xMean = px(stats.mean);
  const xP95 = px(stats.p95);
  const xP99 = px(stats.p99);
  const xStdL = px(Math.max(lo, stats.mean - stats.std));
  const xStdR = px(Math.min(hi, stats.mean + stats.std));
  const stdClipR = stats.mean + stats.std > hi;
  const stdW = Math.max(stats.std > 0 ? 2 : 0, xStdR - xStdL);

  const stdBand = stdW > 0
    ? `<rect x="${xStdL.toFixed(1)}" y="${trackY - 5}" width="${stdW.toFixed(1)}" height="10" rx="3" class="spread-std-band ${skewCls}"/>`
    : '';
  const stdClipMark = stdClipR
    ? `<line x1="${x1}" y1="${trackY - 5}" x2="${x1}" y2="${trackY + 5}" class="spread-std-clip ${skewCls}"/>`
    : '';
  const pullBridge = Math.abs(xMean - xMed) > 2
    ? `<line x1="${xMed.toFixed(1)}" y1="${trackY}" x2="${xMean.toFixed(1)}" y2="${trackY}" class="spread-pull ${skewCls}"/>`
    : '';

  const p50Str = fmt(stats.p50);
  const meanStr = fmt(stats.mean);
  const stdStr = fmt(stats.std);
  const p95Str = fmt(stats.p95);
  const p99Str = fmt(stats.p99);

  const tooltip = {
    serializer: serializerLabel,
    phase: phaseLabel,
    unit,
    p50: p50Str,
    mean: meanStr,
    pullPct: `${pullPct >= 0 ? '+' : ''}${formatSig(pullPct, 2)}%`,
    std: stdStr,
    iqr: stats.p25 != null && stats.p75 != null ? `${fmt(stats.p25)} – ${fmt(stats.p75)}` : null,
    p95: p95Str,
    p99: p99Str,
    p99Ratio: `${formatSig(stats.p99 / stats.p50, 2)}×p50`,
    minmax: `${fmt(stats.min)} – ${fmt(stats.max)}`,
  };

  const md = `p50 ${p50Str} · mean ${meanStr} · ±${stdStr} · p95 ${p95Str} · p99 ${p99Str}`;
  const aria = `${phaseLabel || 'Latency spread'} (${unit}): ${md}`;

  const html =
    `<div class="spread-cell" tabindex="0" role="img" aria-label="${escapeHtml(aria)}" data-spread-tip="${escapeHtml(JSON.stringify(tooltip))}">` +
      `<svg class="spread-svg" width="${W}" height="28" viewBox="0 0 ${W} 28" aria-hidden="true">` +
        `<line x1="${x0}" y1="${trackY}" x2="${x1}" y2="${trackY}" class="spread-rail"/>` +
        `${stdBand}${stdClipMark}` +
        `<line x1="${xMed.toFixed(1)}" y1="${trackY}" x2="${xP95.toFixed(1)}" y2="${trackY}" class="spread-core"/>` +
        `<line x1="${xP95.toFixed(1)}" y1="${trackY}" x2="${xP99.toFixed(1)}" y2="${trackY}" class="spread-tail"/>` +
        `<line x1="${xP95.toFixed(1)}" y1="${trackY - 3.5}" x2="${xP95.toFixed(1)}" y2="${trackY + 3.5}" class="spread-p95-tick"/>` +
        `<circle cx="${xP99.toFixed(1)}" cy="${trackY}" r="2.2" class="spread-p99-dot"/>` +
        `${pullBridge}` +
        `<line x1="${xMed.toFixed(1)}" y1="${trackY - 5}" x2="${xMed.toFixed(1)}" y2="${trackY + 5}" class="spread-p50-tick"/>` +
        `<path d="M ${xMean.toFixed(1)} ${trackY - 4} L ${(xMean - 3.6).toFixed(1)} ${trackY - 10} A 4 4 0 1 1 ${(xMean + 3.6).toFixed(1)} ${trackY - 10} Z" class="spread-pin ${skewCls}"/>` +
      `</svg>` +
      `<div class="spread-labels">` +
        `<span class="spread-lbl-p50">${escapeHtml(p50Str)}</span>` +
        `<span class="spread-lbl-mean ${skewCls}">${showMeanLabel ? `μ ${escapeHtml(meanStr)}` : ''}</span>` +
        `<span class="spread-lbl-p99">${escapeHtml(p99Str)}</span>` +
      `</div>` +
    `</div>`;

  return { html, md, tooltip };
}

/** Compact 1-line legend for the Compare table when spread columns are shown. */
export function spreadLegendHtml() {
  return (
    `<span class="spread-legend-item">` +
      `<svg width="12" height="12" viewBox="0 0 14 14" aria-hidden="true"><path d="M7 13 L3.5 7.5 A3.8 3.8 0 1 1 10.5 7.5 Z" fill="#e37400"/></svg>` +
      `<strong>Mean</strong> pin <span class="spread-legend-muted">(amber/red when outliers pull &gt;12%)</span>` +
    `</span>` +
    `<span class="spread-legend-item">` +
      `<svg width="8" height="12" viewBox="0 0 10 14" aria-hidden="true"><line x1="5" y1="2" x2="5" y2="12" stroke="#174ea6" stroke-width="2.4" stroke-linecap="round"/></svg>` +
      `<strong>p50</strong>` +
    `</span>` +
    `<span class="spread-legend-item">` +
      `<svg width="20" height="10" viewBox="0 0 24 12" aria-hidden="true"><rect x="1" y="2" width="22" height="8" rx="3" fill="#1a73e8" opacity="0.22"/></svg>` +
      `<strong>±1 std</strong>` +
    `</span>` +
    `<span class="spread-legend-item">` +
      `<svg width="24" height="10" viewBox="0 0 28 12" aria-hidden="true"><line x1="1" y1="6" x2="18" y2="6" stroke="#1a73e8" stroke-width="3.2" stroke-linecap="round"/><line x1="18" y1="6" x2="26" y2="6" stroke="#60a5fa" stroke-width="2.2"/><circle cx="26" cy="6" r="2.2" fill="#60a5fa"/></svg>` +
      `<strong>p50 → p95 → p99</strong> <span class="spread-legend-muted">(local p5–p99 · hover for exact stats)</span>` +
    `</span>`
  );
}
