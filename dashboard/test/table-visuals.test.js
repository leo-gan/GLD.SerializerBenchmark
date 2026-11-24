import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LATENCY_US } from '../format.js';
import {
  extractSpreadStats,
  isSpreadMetric,
  migrateSelectedMetrics,
  normalizeAvailableMetrics,
  renderDivergingRatioHtml,
  renderSpreadCellHtml,
  spreadLabel,
  spreadLatencyValues,
} from '../table-visuals.js';

test('normalizeAvailableMetrics replaces mean/std/p50/p95/p99 per phase with one spread metric', () => {
  const raw = [
    'avg_ops_per_sec',
    'avg_time_total_ns',
    'total_std_ns',
    'total_median_ns',
    'total_p50_ns',
    'total_p95_ns',
    'total_p99_ns',
    'total_ci_low_ns',
    'total_cv',
    'avg_time_ser_ns',
    'ser_median_ns',
    'median_size_bytes',
  ];
  const out = normalizeAvailableMetrics(raw);
  assert.ok(out.includes('total_spread_ns'));
  assert.ok(out.includes('ser_spread_ns'));
  assert.ok(!out.includes('deser_spread_ns'));
  assert.ok(!out.includes('avg_time_total_ns'));
  assert.ok(!out.includes('total_median_ns'));
  assert.ok(!out.includes('total_std_ns'));
  assert.ok(!out.includes('total_p95_ns'));
  assert.ok(!out.includes('total_p99_ns'));
  assert.ok(out.includes('avg_ops_per_sec'));
  assert.ok(out.includes('total_ci_low_ns'));
  assert.ok(out.includes('total_cv'));
  assert.ok(out.includes('median_size_bytes'));
});

test('migrateSelectedMetrics collapses legacy latency rows without duplicates', () => {
  const available = ['avg_ops_per_sec', 'total_spread_ns', 'ser_spread_ns', 'median_size_bytes'];
  const legacy = [
    'avg_ops_per_sec',
    'avg_time_total_ns',
    'total_median_ns',
    'total_p95_ns',
    'avg_time_ser_ns',
    'avg_time_deser_ns',
    'median_size_bytes',
  ];
  assert.deepEqual(migrateSelectedMetrics(legacy, available), [
    'avg_ops_per_sec',
    'total_spread_ns',
    'ser_spread_ns',
    'median_size_bytes',
  ]);
});

test('extractSpreadStats and spreadLatencyValues work for complete and sparse groups', () => {
  assert.equal(isSpreadMetric('total_spread_ns'), true);
  assert.equal(isSpreadMetric('avg_ops_per_sec'), false);
  assert.equal(spreadLabel('total_spread_ns', 'µs'), 'Write + read (µs)');
  assert.equal(spreadLabel('ser_spread_ns', 'µs'), 'Write (µs)');
  assert.equal(spreadLabel('deser_spread_ns', 'µs'), 'Read (µs)');

  const full = {
    total_min_ns: 2496,
    total_p5_ns: 3162,
    total_p25_ns: 3851,
    total_median_ns: 4254.8,
    avg_time_total_ns: 4525,
    total_std_ns: 1030,
    total_p75_ns: 5125,
    total_p95_ns: 6554,
    total_p99_ns: 6927,
    total_max_ns: 7408,
  };
  const s = extractSpreadStats(full, 'total_spread_ns');
  assert.equal(s.p50, 4254.8);
  assert.equal(s.mean, 4525);
  assert.equal(s.std, 1030);
  assert.equal(s.p99, 6927);
  assert.equal(spreadLatencyValues([full], ['total_spread_ns']).length, 4);

  assert.equal(extractSpreadStats({}, 'total_spread_ns'), null);
});

test('renderDivergingRatioHtml encodes baseline, symmetry, direction, ties, and overflow', () => {
  const base = renderDivergingRatioHtml({
    valueText: '119',
    ratio: 1,
    higherIsBetter: true,
    isBaseline: true,
  });
  assert.equal(base.isVisual, true);
  assert.match(base.html, /ratio-base-diamond/);
  assert.equal(base.md, '119');

  const doubleBetter = renderDivergingRatioHtml({
    valueText: '238',
    ratio: 2.0,
    higherIsBetter: true,
    ratioTag: 'base',
  });
  const halfWorse = renderDivergingRatioHtml({
    valueText: '59.5',
    ratio: 0.5,
    higherIsBetter: true,
    ratioTag: 'base',
  });
  assert.match(doubleBetter.html, /is-better/);
  assert.match(halfWorse.html, /is-worse/);
  assert.match(doubleBetter.html, /ratio-val-diamond/);
  assert.match(halfWorse.html, /ratio-val-diamond/);
  // Exact log2 symmetry: 2x and 0.5x have identical bar width
  const wDouble = doubleBetter.html.match(/width="([0-9.]+)"/)[1];
  const wHalf = halfWorse.html.match(/width="([0-9.]+)"/)[1];
  assert.equal(wDouble, wHalf);
  assert.equal(doubleBetter.md, '238 (2×base)');

  // Lower-is-better (latency/size): 0.5x is BETTER and extends LEFT (magnitude direction)
  const fasterLat = renderDivergingRatioHtml({
    valueText: '4.25',
    ratio: 0.5,
    higherIsBetter: false,
    ratioTag: 'base',
  });
  assert.match(fasterLat.html, /is-better/);
  assert.match(fasterLat.html, /ratio-val-diamond/);
  const rectX = Number(fasterLat.html.match(/<rect x="([0-9.]+)"/)[1]);
  assert.ok(rectX < 72, 'ratio < 1 should extend left of center (72)');

  // Tie within 1% renders neutral without colored bar, with value diamond at center
  const tie = renderDivergingRatioHtml({
    valueText: '123',
    ratio: 1.004,
    higherIsBetter: false,
  });
  assert.match(tie.html, /is-neutral/);
  assert.match(tie.html, /ratio-val-diamond/);
  assert.doesNotMatch(tie.html, /<rect /);

  // Overflow beyond ±3.5 doublings draws chevron polygon and omits value diamond
  const extremeSlow = renderDivergingRatioHtml({
    valueText: '6.23',
    ratio: 0.05,
    higherIsBetter: true,
  });
  assert.match(extremeSlow.html, /<polygon points="1,5 6,2 6,8"/);
  assert.doesNotMatch(extremeSlow.html, /ratio-val-diamond/);

  const extremeFast = renderDivergingRatioHtml({
    valueText: '2400',
    ratio: 20,
    higherIsBetter: true,
  });
  assert.match(extremeFast.html, /<polygon points="143,5 138,2 138,8"/);
  assert.doesNotMatch(extremeFast.html, /ratio-val-diamond/);

  // Non-directional or invalid ratio falls back cleanly
  const nonDir = renderDivergingRatioHtml({
    valueText: '100',
    ratio: 1.5,
    higherIsBetter: null,
  });
  assert.equal(nonDir.isVisual, false);
});

test('renderSpreadCellHtml renders calm, skewed/clipped, and zero-variance distributions cleanly', () => {
  const calm = renderSpreadCellHtml(
    {
      min: 2496, p5: 3162, p25: 3851, p50: 4254.8,
      mean: 4525, std: 1030, p75: 5125, p95: 6554, p99: 6927, max: 7408,
    },
    LATENCY_US,
    { phaseLabel: 'Total spread', serializerLabel: 'BinaryPack' },
  );
  assert.match(calm.html, /is-calm/);
  assert.doesNotMatch(calm.html, /μ /);
  assert.match(calm.md, /p50 4\.25/);
  assert.doesNotMatch(calm.html, /NaN/);

  // MS Bond Fast deser (All trials): extreme outlier pull (+71%) and mean + std > p99
  const skewed = renderSpreadCellHtml(
    {
      min: 2323, p5: 2810, p25: 3509, p50: 3847,
      mean: 6573, std: 22755, p75: 4769, p95: 7419, p99: 18104, max: 229366,
    },
    LATENCY_US,
    { phaseLabel: 'Deserialize spread', serializerLabel: 'MS Bond Fast' },
  );
  assert.match(skewed.html, /is-high-skew/);
  assert.match(skewed.html, /μ 6\.57/);
  assert.match(skewed.html, /spread-std-clip/);
  assert.match(skewed.html, /spread-pull/);
  assert.doesNotMatch(skewed.html, /NaN/);

  // Zero-variance single sample: must never emit NaN
  const flat = renderSpreadCellHtml(
    { min: 5000, p5: 5000, p25: 5000, p50: 5000, mean: 5000, std: 0, p75: 5000, p95: 5000, p99: 5000, max: 5000 },
    LATENCY_US,
  );
  assert.doesNotMatch(flat.html, /NaN/);
});
