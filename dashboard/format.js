/**
 * Shared number formatting for dashboard tables and charts.
 *
 * Contract:
 * - Continuous metrics: 3 significant digits, unitless cells (unit in header).
 * - Byte sizes and sample counts: locale-grouped integers (e.g. 29,577).
 * - Ratio cells: absolute + (ratio×) with better/worse class names.
 */

const SIG = 3;

/** Format a finite number to `sig` significant digits (no unit suffix). */
export function formatSig(value, sig = SIG) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value !== 'number' || !Number.isFinite(value)) return String(value);
  if (value === 0) return '0';

  const abs = Math.abs(value);
  // toPrecision already enforces significant digits (may yield scientific notation)
  let s = Number(value).toPrecision(sig);
  // Normalize exponent form: 1.24e+6 → 1.24e6
  if (/e/i.test(s)) {
    return s.replace(/e\+/i, 'e').replace(/e-0+/i, 'e-');
  }
  // Trim trailing zeros on decimals (keep integers clean)
  if (s.includes('.')) {
    s = s.replace(/\.?0+$/, '');
  }
  // Group thousands for large fixed values still in decimal form
  const n = Number(s);
  if (Number.isFinite(n) && Math.abs(n) >= 1000) {
    return n.toLocaleString('en-US', { maximumSignificantDigits: sig });
  }
  return s;
}

/** Locale-grouped integer (sizes, counts). */
export function formatIntGrouped(value) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value !== 'number' || !Number.isFinite(value)) return String(value);
  return Math.round(value).toLocaleString('en-US');
}

/** Choose latency display unit from a set of ns values. */
export function chooseLatencyUnit(valuesNs) {
  const nums = (valuesNs || []).filter((v) => typeof v === 'number' && Number.isFinite(v) && v > 0);
  if (!nums.length) return { unit: 'ns', divisor: 1, header: 'ns' };
  const max = Math.max(...nums);
  if (max >= 1e6) return { unit: 'ms', divisor: 1e6, header: 'ms' };
  if (max >= 1e3) return { unit: 'µs', divisor: 1e3, header: 'µs' };
  return { unit: 'ns', divisor: 1, header: 'ns' };
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
  if (key === 'runs' || key === 'runs_raw' || key === 'outliers_removed') return 'count';
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
 * Ratio = value / baseline (always).
 * Returns { text, ratio, className } for cell rendering.
 */
export function formatRelativeCell(value, baseline, higherIsBetter, scales, key) {
  const abs = formatMetricCell(key, value, scales);
  if (
    value === null ||
    value === undefined ||
    baseline === null ||
    baseline === undefined ||
    typeof value !== 'number' ||
    typeof baseline !== 'number' ||
    !Number.isFinite(value) ||
    !Number.isFinite(baseline) ||
    baseline === 0
  ) {
    return { text: abs, ratio: null, className: 'num' };
  }

  const ratio = value / baseline;
  const ratioText = `${formatSig(ratio)}×`;
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
    latency: chooseLatencyUnit(lat),
    ops: chooseOpsUnit(ops),
  };
}
