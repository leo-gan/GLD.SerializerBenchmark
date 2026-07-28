/**
 * Shared number formatting for dashboard tables and charts.
 *
 * Contract:
 * - Continuous metrics: 3 significant digits, unitless cells (unit in header).
 * - Byte sizes and sample counts: locale-grouped integers (e.g. 29,577).
 * - Ratio cells: absolute + (ratio×) with better/worse class names.
 */

const SIG = 3;

/**
 * Format a finite number to `sig` significant digits in **fixed-point only**
 * (never scientific / exponential). Examples: 1100 → "1,100", 0.644 → "0.644".
 */
export function formatSig(value, sig = SIG) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value !== 'number' || !Number.isFinite(value)) return String(value);
  if (value === 0) return '0';

  const abs = Math.abs(value);
  // Round to `sig` significant digits without using exponential display.
  const order = Math.floor(Math.log10(abs));
  const scale = 10 ** (sig - 1 - order);
  const rounded = Math.round(value * scale) / scale;

  // Fraction digits needed so the least significant digit of `sig` is visible.
  const decimals = Math.max(0, sig - 1 - order);

  if (decimals === 0) {
    return Math.round(rounded).toLocaleString('en-US');
  }

  // Fixed-point with thousands separators; strip trailing zeros after the point.
  let s = rounded.toLocaleString('en-US', {
    useGrouping: true,
    minimumFractionDigits: 0,
    maximumFractionDigits: decimals,
  });
  // Guard: some engines can still emit exp for extreme values — force fixed.
  if (/e/i.test(s)) {
    s = rounded.toFixed(decimals).replace(/\.?0+$/, '');
    // Add grouping to integer part
    const neg = s.startsWith('-');
    const body = neg ? s.slice(1) : s;
    const [ip, fp] = body.split('.');
    const grouped = Number(ip).toLocaleString('en-US');
    s = (neg ? '-' : '') + grouped + (fp != null && fp !== '' ? `.${fp}` : '');
  }
  return s;
}

/**
 * Docs Summary-table style label: ``simd-json:0.14.3`` when version is known.
 * Matches analysis/reports.py: ``f"{name}:{version}" if version else name``.
 */
export function serializerDisplayName(serializer, version) {
  const name = serializer == null ? '' : String(serializer).trim();
  if (!name) return '—';
  const ver =
    version == null || version === ''
      ? ''
      : String(version).trim();
  if (!ver || ver === 'unknown' || ver === '—') return name;
  // Avoid double-suffix if caller already passed "name:ver"
  if (name.includes(':') && name.endsWith(ver)) return name;
  return `${name}:${ver}`;
}

/** Label from a stats group object (uses serializer_version when present). */
export function serializerLabelFromGroup(g) {
  if (!g) return '—';
  return serializerDisplayName(g.serializer, g.serializer_version);
}

/** Locale-grouped integer (sizes, counts). */
export function formatIntGrouped(value) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value !== 'number' || !Number.isFinite(value)) return String(value);
  return Math.round(value).toLocaleString('en-US');
}

/** Fixed µs scale for roster/compare latency columns. */
export const LATENCY_US = { unit: 'µs', divisor: 1e3, header: 'µs' };

/**
 * Choose latency display unit from a set of ns values.
 *
 * Prefer **microseconds** for table columns. Serializer encode/decode times
 * usually sit in the µs–ms band: ms collapses fast codecs to awkward decimals
 * (e.g. 0.012 ms vs 12.3 µs), while a fixed µs scale keeps 3-sig values
 * comparable across total / ser / deser without unit hopping when one slow
 * row would otherwise force the whole column into milliseconds.
 *
 * - max < 1 µs  → ns (sub-microsecond niche)
 * - otherwise   → µs (including multi-ms latencies, shown as e.g. 12,400)
 * - never auto-ms for roster/compare tables
 */
export function chooseLatencyUnit(valuesNs) {
  const nums = (valuesNs || []).filter((v) => typeof v === 'number' && Number.isFinite(v) && v > 0);
  if (!nums.length) return LATENCY_US;
  const max = Math.max(...nums);
  if (max < 1e3) return { unit: 'ns', divisor: 1, header: 'ns' };
  return LATENCY_US;
}

/** Choose throughput scale from ops/s values. */
export function chooseOpsUnit(valuesOps) {
  const nums = (valuesOps || []).filter((v) => typeof v === 'number' && Number.isFinite(v) && v > 0);
  if (!nums.length) return { unit: 'ops', divisor: 1, header: 'Ops/s' };
  const max = Math.max(...nums);
  if (max >= 1e6) return { unit: 'M', divisor: 1e6, header: 'Ops/s (M)' };
  if (max >= 1e3) return { unit: 'k', divisor: 1e3, header: 'Ops/s (k)' };
  return { unit: 'ops', divisor: 1, header: 'Ops/s' };
}

export function formatLatencyCell(ns, scale) {
  if (ns === null || ns === undefined || !Number.isFinite(ns)) return '—';
  const s = scale || { divisor: 1 };
  return formatSig(ns / s.divisor);
}

export function formatOpsCell(ops, scale) {
  if (ops === null || ops === undefined || !Number.isFinite(ops)) return '—';
  const s = scale || { divisor: 1 };
  return formatSig(ops / s.divisor);
}

/**
 * Compact formats WITH unit — for chart tooltips/axes only (not table cells).
 */
export function formatTimeCompact(ns) {
  if (ns === null || ns === undefined || !Number.isFinite(ns)) return '—';
  if (ns < 1000) return `${formatSig(ns)} ns`;
  if (ns < 1e6) return `${formatSig(ns / 1e3)} µs`;
  return `${formatSig(ns / 1e6)} ms`;
}

export function formatOpsCompact(ops) {
  if (ops === null || ops === undefined || !Number.isFinite(ops)) return '—';
  if (ops < 1000) return `${formatSig(ops)}/s`;
  if (ops < 1e6) return `${formatSig(ops / 1e3)}k/s`;
  return `${formatSig(ops / 1e6)}M/s`;
}

/** Infer metric kind for table formatting. */
export function metricKind(key) {
  if (!key) return 'other';
  if (key.endsWith('_ns') || key.includes('_time_') || key.includes('latency')) return 'latency';
  if (
    key.includes('ops_per_sec') ||
    key.endsWith('_ops_mean') ||
    key.endsWith('_ops_median') ||
    key.endsWith('_ops_p95')
  ) {
    return 'ops';
  }
  if (key.endsWith('_bytes') || key.startsWith('size_') || key === 'median_size_bytes') return 'bytes';
  if (
    key === 'runs' ||
    key === 'runs_raw' ||
    key === 'outliers_removed' ||
    key === 'values_clipped' ||
    key === 'warmup_skipped'
  )
    return 'count';
  if (typeof key === 'string' && (key.includes('fidelity') || key.includes('cv') || key.includes('delta') || key.includes('hedges'))) {
    return 'ratio';
  }
  return 'other';
}

/**
 * Format a metric cell value without unit suffix.
 * Optional `scales` map: { latency: chooseLatencyUnit(...), ops: chooseOpsUnit(...) }
 */
export function formatMetricCell(key, value, scales = {}) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'string') return value;
  if (typeof value !== 'number' || !Number.isFinite(value)) return String(value);

  const kind = metricKind(key);
  if (kind === 'latency') return formatLatencyCell(value, scales.latency);
  if (kind === 'ops') return formatOpsCell(value, scales.ops);
  if (kind === 'bytes' || kind === 'count') return formatIntGrouped(value);
  if (kind === 'ratio') return formatSig(value);
  if (Number.isInteger(value) && Math.abs(value) < 1e9) return formatIntGrouped(value);
  return formatSig(value);
}

/** Header label with unit for a metric key given column scales. */
export function metricHeaderLabel(key, scales = {}) {
  const kind = metricKind(key);
  const base = key
    .replace(/_ns$/g, '')
    .replace(/_bytes$/g, '')
    .replace(/_per_sec$/g, '')
    .replace(/_/g, ' ');

  if (kind === 'latency') {
    const u = scales.latency?.header || 'ns';
    return `${base} (${u})`;
  }
  if (kind === 'ops') {
    return scales.ops?.header || 'Ops/s';
  }
  if (kind === 'bytes') {
    return key.includes('memory') ? `${base} (bytes)` : `${base} (bytes)`;
  }
  return base;
}

/**
 * Ratio = value / reference.
 * @param {string} [ratioTag=''] suffix after ×, e.g. '' → "0.93×", 'med' → "0.93×med", 'base' → "0.93×base"
 * Returns { text, ratio, className } for cell rendering.
 */
export function formatRelativeCell(value, reference, higherIsBetter, scales, key, ratioTag = '') {
  const abs =
    key && (String(key).startsWith('ops_') || key === 'avg_ops_per_sec')
      ? formatOpsCell(value, scales?.ops)
      : formatMetricCell(key, value, scales);
  if (
    value === null ||
    value === undefined ||
    reference === null ||
    reference === undefined ||
    typeof value !== 'number' ||
    typeof reference !== 'number' ||
    !Number.isFinite(value) ||
    !Number.isFinite(reference) ||
    reference === 0
  ) {
    return { text: abs, ratio: null, className: 'num' };
  }

  const ratio = value / reference;
  // Multiplier: 2 significant digits is enough (0.931× → 0.93×)
  const tag = ratioTag ? `×${ratioTag}` : '×';
  const ratioText = `${formatSig(ratio, 2)}${tag}`;
  let className = 'num rel-neutral';
  if (higherIsBetter === true || higherIsBetter === false) {
    const better = higherIsBetter ? ratio > 1 + 1e-9 : ratio < 1 - 1e-9;
    const worse = higherIsBetter ? ratio < 1 - 1e-9 : ratio > 1 + 1e-9;
    if (better) className = 'num rel-better';
    else if (worse) className = 'num rel-worse';
  }
  return {
    text: `${abs} (${ratioText})`,
    ratio,
    className,
  };
}

/** Build latency/ops scales from a list of groups for consistent columns. */
export function scalesFromGroups(groups, keys = null) {
  const gs = groups || [];
  const lat = [];
  const ops = [];
  for (const g of gs) {
    if (!g) continue;
    if (!keys) {
      if (typeof g.avg_time_total_ns === 'number') lat.push(g.avg_time_total_ns);
      if (typeof g.avg_time_ser_ns === 'number') lat.push(g.avg_time_ser_ns);
      if (typeof g.avg_time_deser_ns === 'number') lat.push(g.avg_time_deser_ns);
      if (typeof g.avg_ops_per_sec === 'number') ops.push(g.avg_ops_per_sec);
    } else {
      for (const k of keys) {
        const v = g[k];
        if (typeof v !== 'number' || !Number.isFinite(v)) continue;
        const kind = metricKind(k);
        if (kind === 'latency') lat.push(v);
        if (kind === 'ops') ops.push(v);
      }
    }
  }
  return {
    // Tables always normalize latency to µs (see chooseLatencyUnit).
    latency: lat.length ? chooseLatencyUnit(lat) : LATENCY_US,
    ops: chooseOpsUnit(ops),
  };
}
