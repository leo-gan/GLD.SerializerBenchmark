import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  ALL_LANG,
  compareLabel,
  displayTier,
  flattenLanguageRows,
  isAllLang,
  mixedLanguages,
  peerRows,
  rowsToDelimited,
  skipReason,
  sortRows,
  totalStdUs,
} from '../exp-export.js';
import { figureTypesFor, sizeTreatment, usesExperimentGraphs, wrapYTick } from '../exp-charts.js';

test('totalStdUs reconstructs from mean CI', () => {
  const std = totalStdUs({
    total_ci_low_ns: 3788,
    total_ci_high_ns: 4088,
    runs: 92,
  });
  assert.ok(std != null);
  assert.ok(Math.abs(std - 0.734) < 0.002);
});

test('totalStdUs prefers published total_std_ns', () => {
  assert.equal(
    totalStdUs({
      total_std_ns: 1000,
      total_ci_low_ns: 3788,
      total_ci_high_ns: 4088,
      runs: 92,
    }),
    1
  );
});

test('totalStdUs is null without std or usable CI', () => {
  assert.equal(totalStdUs({ runs: 1, total_ci_low_ns: 1, total_ci_high_ns: 2 }), null);
  assert.equal(totalStdUs({}), null);
});

test('sizeTreatment Python memory is S0 with gzip and msgspec', () => {
  const rows = [
    { library: 'orjson', size_bytes: 448, size_gzip_bytes: 229, in_comparison: true },
    { library: 'json', size_bytes: 448, size_gzip_bytes: 229, in_comparison: true },
    { library: 'msgspec', size_bytes: 192, size_gzip_bytes: 165, in_comparison: false, writes_named_fields: false },
  ];
  const t = sizeTreatment(rows);
  assert.equal(t.kind, 'S0');
  assert.equal(
    t.text,
    'Named JSON 448 B (229 after gzip). msgspec also ran (192 B). By design it writes a JSON list, not {"id": …}, so we do not rank it here.'
  );
});

test('skipReason explains msgspec is timed, not failed', () => {
  const skip = skipReason({
    library: 'msgspec',
    in_comparison: false,
    writes_named_fields: false,
  });
  assert.equal(skip.short, 'writes […] on purpose');
  assert.equal(skip.label, 'By design — JSON list');
  assert.match(skip.detail, /By design/i);
  assert.match(skip.detail, /list/);
  assert.equal(compareLabel({ in_comparison: false, writes_named_fields: false }), 'By design — JSON list');
  assert.equal(skipReason({ in_comparison: true, writes_named_fields: true }), null);
});

test('displayTier does not paint a 2% median gap as clearly slower', () => {
  const rows = [
    { library: 'IkigaJSON', total_median_ns: 54370, tier: 'fastest', in_comparison: true, writes_named_fields: true },
    {
      library: 'Foundation.JSONEncoder',
      total_median_ns: 55748,
      tier: 'slower',
      cliffs_delta_vs_fastest: 0.4554,
      in_comparison: true,
      writes_named_fields: true,
    },
  ];
  assert.equal(displayTier(rows[0], rows), 'fastest');
  assert.equal(displayTier(rows[1], rows), 'similar');
});

test('displayTier colors stream rows even when in_comparison is false', () => {
  const rows = [
    { library: 'fast', total_median_ns: 1000, in_comparison: false, writes_named_fields: true, io: 'stream' },
    { library: 'mid', total_median_ns: 1100, in_comparison: false, writes_named_fields: true, io: 'stream' },
    { library: 'slow', total_median_ns: 3000, in_comparison: false, writes_named_fields: true, io: 'stream' },
  ];
  assert.equal(displayTier(rows[0], rows), 'fastest');
  assert.equal(displayTier(rows[1], rows), 'similar');
  assert.equal(displayTier(rows[2], rows), 'slower');
  assert.equal(skipReason(rows[0]), null);
});

test('sizeTreatment JavaScript is S0 without gzip', () => {
  const rows = [
    { library: 'JSON.stringify', size_bytes: 448, size_gzip_bytes: null, in_comparison: true },
    { library: 'fast-json-stringify', size_bytes: 448, in_comparison: true },
  ];
  const t = sizeTreatment(rows);
  assert.equal(t.kind, 'S0');
  assert.equal(t.text, 'Named JSON 448 B.');
});

test('sizeTreatment C# is S1', () => {
  const rows = [
    { library: 'SpanJson', size_bytes: 440, in_comparison: true },
    { library: 'System.Text.Json', size_bytes: 588, in_comparison: true },
    { library: 'Json.Net', size_bytes: 972, in_comparison: true },
    { library: 'FsPicklerJson', size_bytes: 1024, in_comparison: true },
  ];
  assert.equal(sizeTreatment(rows).kind, 'S1');
});

test('rowsToDelimited includes skipped rows and empty gzip', () => {
  const csv = rowsToDelimited(
    [
      {
        library: 'orjson',
        version: '3.11.9',
        io: 'memory',
        write_median_ns: 1522,
        read_median_ns: 2362,
        total_median_ns: 3894,
        total_ci_low_ns: 3788,
        total_ci_high_ns: 4088,
        size_bytes: 448,
        size_gzip_bytes: 229,
        runs: 92,
        runs_raw: 100,
        tier: 'fastest',
        in_comparison: true,
      },
      {
        library: 'msgspec',
        version: '0.19.0',
        io: 'memory',
        write_median_ns: 1000,
        read_median_ns: 2000,
        total_median_ns: 3000,
        size_bytes: 192,
        runs: 90,
        in_comparison: false,
        writes_named_fields: false,
      },
    ],
    { delimiter: ',' }
  );
  const lines = csv.trim().split('\n');
  assert.equal(
    lines[0],
    'library,version,io,write_us,read_us,total_us,spread_std_us,size_bytes,size_gzip_bytes,trials,trials_raw,vs_fastest,in_comparison'
  );
  assert.match(lines[1], /^orjson,3\.11\.9,memory,/);
  assert.match(lines[1], /,true$/);
  const skip = lines.find((l) => l.startsWith('msgspec,'));
  assert.ok(skip);
  assert.match(skip, /By design — JSON list/);
  assert.match(skip, /,false$/);
  const skipCols = skip.split(',');
  const gzipIdx = lines[0].split(',').indexOf('size_gzip_bytes');
  assert.equal(skipCols[gzipIdx], '');
});

test('wrapYTick keeps short names on one line', () => {
  assert.deepEqual(wrapYTick({ library: 'orjson', tier: 'fastest' }), ['● orjson']);
  assert.deepEqual(wrapYTick({ library: 'System.Text.Json', tier: 'slower' }), ['× System.Text.Json']);
});

test('wrapYTick splits slash names and prefixes only the first line', () => {
  const tick = wrapYTick({ library: 'segmentio/encoding/json', tier: 'slower' });
  assert.equal(tick[0].startsWith('× '), true);
  assert.equal(tick.length, 2);
  assert.equal(tick[0], '× segmentio/');
  assert.equal(tick[1], 'encoding/json');
});

test('usesExperimentGraphs is on for every experiment id', () => {
  assert.equal(usesExperimentGraphs('01-json-library-bakeoff'), true);
  assert.equal(usesExperimentGraphs('13-ranking-accident'), true);
  assert.equal(usesExperimentGraphs('unknown'), false);
});

test('All tab flattens languages and keeps vs-fastest inside each language', () => {
  assert.equal(isAllLang(ALL_LANG), true);
  assert.equal(isAllLang('python'), false);
  const languages = {
    rust: {
      status: 'ok',
      rows: [
        { library: 'sonic-rs', total_median_ns: 1300, tier: 'fastest', in_comparison: true },
        { library: 'serde_json', total_median_ns: 4000, tier: 'slower', in_comparison: true },
      ],
    },
    java: {
      status: 'ok',
      rows: [
        { library: 'jsoniter', total_median_ns: 42700, tier: 'fastest', in_comparison: true },
        { library: 'jackson', total_median_ns: 92800, tier: 'slower', in_comparison: true },
      ],
    },
    go: { status: 'missing', rows: [] },
  };
  const flat = flattenLanguageRows(languages, ['rust', 'java', 'go']);
  assert.equal(flat.length, 4);
  assert.equal(mixedLanguages(flat), true);
  assert.deepEqual(
    peerRows(flat[2], flat).map((r) => r.library),
    ['jsoniter', 'jackson']
  );
  assert.equal(displayTier(flat[2], flat), 'fastest');
  assert.equal(displayTier(flat[3], flat), 'slower');
  assert.equal(displayTier(flat[0], flat), 'fastest');
  const ordered = sortRows(flat).map((r) => `${r.language}:${r.library}`);
  assert.deepEqual(ordered, ['rust:sonic-rs', 'rust:serde_json', 'java:jsoniter', 'java:jackson']);
});

test('rowsToDelimited prefixes language on All-tab rows', () => {
  const csv = rowsToDelimited(
    [
      {
        language: 'python',
        library: 'orjson',
        io: 'memory',
        write_median_ns: 1522,
        read_median_ns: 2362,
        total_median_ns: 3894,
        size_bytes: 448,
        runs: 92,
        tier: 'fastest',
        in_comparison: true,
      },
      {
        language: 'go',
        library: 'goccy/go-json',
        io: 'memory',
        write_median_ns: 1000,
        read_median_ns: 2000,
        total_median_ns: 3000,
        size_bytes: 448,
        runs: 90,
        tier: 'fastest',
        in_comparison: true,
      },
    ],
    { delimiter: ',' }
  );
  const header = csv.trim().split('\n')[0];
  assert.equal(header.startsWith('language,library,'), true);
  assert.match(csv, /^python,orjson,/m);
  assert.match(csv, /^go,goccy\/go-json,/m);
});

test('wrapYTick prefers the All-tab language · library label', () => {
  assert.deepEqual(wrapYTick({ library: 'orjson', label: 'Python · orjson', tier: 'fastest' }), [
    '● Python · orjson',
  ]);
});

test('figureTypesFor All tab uses the same microsecond figures as a language tab', () => {
  const timed = [
    { library: 'a', language: 'rust', write_median_ns: 1, read_median_ns: 2, total_median_ns: 3, size_bytes: 10, in_comparison: true },
    { library: 'b', language: 'java', write_median_ns: 20, read_median_ns: 40, total_median_ns: 60, size_bytes: 20, in_comparison: true },
  ];
  const all = figureTypesFor('01-json-library-bakeoff', timed, timed, { crossLang: true });
  const one = figureTypesFor('01-json-library-bakeoff', timed, timed);
  assert.deepEqual(all, one);
  assert.ok(all.includes('L1'));
  assert.ok(!all.includes('A1'));
  assert.deepEqual(figureTypesFor('04-sensor-list-size', timed, timed, { crossLang: true }), ['C1']);
  assert.deepEqual(figureTypesFor('09-compression-size', timed, timed, { crossLang: true }), ['S2']);
  assert.ok(figureTypesFor('10-one-vs-hundred', timed, timed, { crossLang: true }).includes('C2'));
  assert.ok(figureTypesFor('10-one-vs-hundred', timed, timed, { crossLang: true }).includes('L1'));
});

test('figureTypesFor picks a story-specific hero', () => {
  const timed = [
    { library: 'a', write_median_ns: 1, read_median_ns: 2, total_median_ns: 3, size_bytes: 10, in_comparison: true },
    { library: 'b', write_median_ns: 2, read_median_ns: 4, total_median_ns: 6, size_bytes: 20, in_comparison: true },
  ];
  assert.deepEqual(figureTypesFor('07-write-once-read-many', timed), ['W1', 'S1']);
  assert.deepEqual(figureTypesFor('04-sensor-list-size', timed), ['C1']);
  assert.deepEqual(figureTypesFor('09-compression-size', timed), ['S2']);
  assert.ok(figureTypesFor('10-one-vs-hundred', timed).includes('C2'));
  assert.ok(figureTypesFor('13-ranking-accident', timed).includes('R1'));
  const def = figureTypesFor('02-flat-record-formats', timed);
  assert.ok(def.includes('L1'));
  assert.ok(def.includes('W1'));
  assert.ok(def.includes('S1'));
});
