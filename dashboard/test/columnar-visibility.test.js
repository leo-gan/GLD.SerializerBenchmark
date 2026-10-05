import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { catalogMissing, classifySerializer } from '../compliance-classify.js';
import {
  auditComplianceGroups,
  benchMapFromGroups,
  formatLabel,
  complianceHeatmap,
  formatSubset,
  noSpecEntries,
  standardMenuOptions,
  standardOptionIds,
} from '../compliance-groups.js';
import { discoverFixtureOptions } from '../fixture-types.js';

const dataDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'data');
const COLUMNAR = ['table', 'table_project', 'nested_table', 'signal'];

function loadJsonGz(name) {
  const buf = readFileSync(join(dataDir, name));
  const raw = buf[0] === 0x1f && buf[1] === 0x8b ? gunzipSync(buf) : buf;
  return JSON.parse(raw.toString('utf8'));
}

function baseType(testData) {
  const raw = String(testData || '');
  const cut = raw.indexOf('@n=');
  return cut >= 0 ? raw.slice(0, cut) : raw;
}

function rowCounts(groups) {
  const counts = { message: 0, document: 0, telemetry: 0, strings: 0, event: 0 };
  for (const group of groups || []) {
    const base = baseType(group.test_data);
    if (base in counts) counts[base] += 1;
  }
  return counts;
}

/** Five-type group counts from the snapshots before the columnar append. */
// One parent row per serializer after I/O fold (bytes+stream are no longer two groups).
const ROW_COUNTS = {
  python: { message: 36, document: 36, telemetry: 36, strings: 36, event: 36 },
  cpp: { message: 58, document: 58, telemetry: 58, strings: 58, event: 58 },
  csharp: { message: 94, document: 92, telemetry: 92, strings: 92, event: 94 },
  go: { message: 44, document: 44, telemetry: 44, strings: 44, event: 44 },
  java: { message: 42, document: 42, telemetry: 42, strings: 42, event: 42 },
  rust: { message: 35, document: 35, telemetry: 35, strings: 36, event: 35 },
  javascript: { message: 44, document: 44, telemetry: 44, strings: 44, event: 44 },
  kotlin: { message: 52, document: 52, telemetry: 52, strings: 52, event: 52 },
};

const RUN_IDS = {
  python: '2026-09-29-183133',
  cpp: '2026-09-14-132646',
  csharp: '2026-09-30-130138',
  go: '2026-10-01-214434',
  java: '2026-09-14-133226',
  rust: '2026-09-29-183721',
  javascript: '2026-09-29-183620',
  kotlin: '2026-09-14-133310',
};

const MUST_HAVE = {
  python: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'orc', 'orc-uncompressed'],
  cpp: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'orc', 'orc-uncompressed', 'sbe'],
  csharp: ['arrow-ipc', 'parquet', 'parquet-uncompressed'],
  go: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'sbe'],
  java: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'orc', 'orc-uncompressed', 'sbe'],
  rust: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'sbe'],
  javascript: ['arrow-ipc', 'parquet', 'parquet-uncompressed'],
  kotlin: ['arrow-ipc', 'parquet', 'parquet-uncompressed', 'orc', 'orc-uncompressed', 'sbe'],
};

const MUST_NOT = {
  python: ['sbe'],
  csharp: ['orc', 'sbe'],
  go: ['orc'],
  rust: ['orc'],
  javascript: ['orc', 'sbe'],
};

test('columnar data types are selectable and stay out of all@all', () => {
  const groups = [
    { test_data: 'message@n=1', data_type_instance_count: 1 },
    { test_data: 'message@n=100', data_type_instance_count: 100 },
    { test_data: 'table@n=1', data_type_instance_count: 1 },
    { test_data: 'table@n=100', data_type_instance_count: 100 },
    { test_data: 'table@n=10000', data_type_instance_count: 10000 },
    { test_data: 'signal@n=100', data_type_instance_count: 100 },
  ];
  const discovered = discoverFixtureOptions(groups);
  assert.ok(discovered.natural.includes('table@n=1'));
  assert.ok(discovered.natural.includes('table@n=10000'));
  assert.ok(discovered.natural.includes('signal@n=100'));
  assert.ok(discovered.batchCompound.includes('message@n=1+100'));
  assert.ok(discovered.batchCompound.includes('table@n=1+100'));
  assert.equal(discovered.batchCompound.includes('signal@n=1+100'), false);
  assert.deepEqual(discovered.allTypes, ['all@1', 'all@100']);
  assert.deepEqual(discovered.allAll, ['all@all']);

  const onlyColumnar = discoverFixtureOptions([
    { test_data: 'table@n=1', data_type_instance_count: 1 },
  ]);
  assert.deepEqual(onlyColumnar.allTypes, []);
  assert.deepEqual(onlyColumnar.allAll, []);
  assert.ok(onlyColumnar.natural.includes('table@n=1'));
});

test('Arrow, Parquet, ORC, and SBE are compliance standards', () => {
  assert.equal(formatLabel('arrow'), 'Arrow IPC');
  assert.equal(formatLabel('parquet'), 'Parquet');
  assert.equal(formatLabel('orc'), 'ORC');
  assert.equal(formatLabel('sbe'), 'SBE');
  for (const id of ['arrow', 'parquet', 'orc', 'sbe']) {
    assert.ok(standardOptionIds().includes(id));
  }
  assert.deepEqual(classifySerializer('python', 'arrow-ipc'), ['arrow']);
  assert.deepEqual(classifySerializer('python', 'parquet-uncompressed'), ['parquet']);
  assert.deepEqual(classifySerializer('python', 'orc'), ['orc']);
  assert.equal(catalogMissing('python', 'sbe'), true);
  assert.deepEqual(classifySerializer('cpp', 'sbe'), ['sbe']);
  assert.deepEqual(classifySerializer('csharp', 'arrow-ipc'), ['arrow']);
  assert.deepEqual(classifySerializer('javascript', 'parquet'), ['parquet']);
  assert.deepEqual(classifySerializer('kotlin', 'orc-uncompressed'), ['orc']);
  assert.deepEqual(classifySerializer('go', 'sbe'), ['sbe']);
  assert.deepEqual(classifySerializer('rust', 'parquet-uncompressed'), ['parquet']);
  assert.equal(catalogMissing('rust', 'orc'), true);
});

test('spliced snapshots keep the five-type matrix and add columnar groups', () => {
  for (const [lang, expectedRows] of Object.entries(ROW_COUNTS)) {
    const stats = loadJsonGz(`stats_${lang}_latest.json.gz`);
    const payload = loadJsonGz(`${lang}_latest.json.gz`);
    assert.equal(payload.run_id, RUN_IDS[lang], lang);
    assert.deepEqual(rowCounts(stats.groups), expectedRows, `${lang} stats row counts`);
    assert.deepEqual(rowCounts(payload.stats.groups), expectedRows, `${lang} payload row counts`);
    assert.equal(stats.groups.length, payload.stats.groups.length, lang);
    assert.equal(stats.columnar_splice.note, payload.columnar_splice.note, lang);
    assert.match(stats.columnar_splice.note, /were not recomputed/);
    assert.ok((stats.columnar_splice.reps || []).every((n) => n >= 50), lang);
    const columnarNames = new Set();
    for (const group of stats.groups) {
      if (COLUMNAR.includes(baseType(group.test_data))) columnarNames.add(group.serializer);
    }
    for (const name of MUST_HAVE[lang]) {
      assert.ok(columnarNames.has(name), `${lang} missing ${name}`);
    }
    for (const name of MUST_NOT[lang] || []) {
      assert.equal(columnarNames.has(name), false, `${lang} should not publish ${name}`);
    }
    assert.ok(
      stats.groups.some((g) => g.serializer === 'arrow-ipc' && baseType(g.test_data) === 'table'),
      `${lang} arrow-ipc table`,
    );

    const bench = { [lang]: benchMapFromGroups(stats.groups) };
    const audit = auditComplianceGroups({ language: lang, benchVersions: bench, matrix: [] });
    assert.deepEqual(audit.issues, [], `${lang} compliance partition:\n${audit.issues.join('\n')}`);
    const arrow = formatSubset([], 'arrow', lang, bench).map((e) => e.serializer);
    assert.ok(arrow.includes('arrow-ipc'), lang);
    const noSpec = noSpecEntries({ language: lang, benchVersions: bench, matrix: [] }).map((e) => e.serializer);
    assert.equal(noSpec.includes('arrow-ipc'), false, lang);
    assert.equal(noSpec.includes('parquet'), false, lang);
  }
});

test('C# columnar snapshot is one published parent per cell', () => {
  const stats = loadJsonGz('stats_csharp_latest.json.gz');
  const modes = new Set(
    stats.groups.filter((g) => g.serializer === 'arrow-ipc').map((g) => g.mode),
  );
  assert.deepEqual([...modes], ['published']);
});

test('columnar standards render a version column of empty cells', () => {
  function heatFor(lang, format) {
    const stats = loadJsonGz(`stats_${lang}_latest.json.gz`);
    const bench = { [lang]: benchMapFromGroups(stats.groups) };
    const extras = formatSubset([], format, lang, bench);
    assert.ok(extras.length > 0, `${lang} ${format}`);
    return complianceHeatmap([], {
      format,
      language: lang,
      benchVersions: bench,
      extras,
    });
  }

  const arrow = heatFor('python', 'arrow');
  assert.deepEqual(arrow.columns.map((column) => column.standard), ['Arrow IPC stream']);
  assert.ok(arrow.rows.some((row) => row.serializer === 'arrow-ipc'));

  const parquet = heatFor('javascript', 'parquet');
  assert.deepEqual(parquet.columns.map((column) => column.standard), ['Parquet file format']);
  assert.ok(parquet.rows.some((row) => row.serializer === 'parquet-uncompressed'));

  const orc = heatFor('java', 'orc');
  assert.deepEqual(orc.columns.map((column) => column.standard), ['ORC v0', 'ORC v1']);
  assert.ok(orc.rows.some((row) => row.serializer === 'orc-uncompressed'));

  const sbe = heatFor('cpp', 'sbe');
  assert.deepEqual(sbe.columns.map((column) => column.standard), ['SBE 1.0']);
  assert.deepEqual(sbe.rows.map((row) => row.serializer), ['sbe']);

  for (const heat of [arrow, parquet, orc, sbe]) {
    assert.ok(heat.rows.every((row) => row.byStandard.size === 0));
  }

  const pythonSbe = formatSubset(
    [],
    'sbe',
    'python',
    { python: benchMapFromGroups(loadJsonGz('stats_python_latest.json.gz').groups) },
  );
  assert.deepEqual(pythonSbe, []);
});

test('published compliance matrix scores Arrow, Parquet, ORC v1, and SBE', () => {
  const doc = loadJsonGz('compliance.json.gz');
  const cells = doc.matrix.filter((cell) =>
    ['arrow', 'parquet', 'orc', 'sbe'].includes(cell.format),
  );
  assert.equal(cells.length, 37);
  assert.ok(cells.every((cell) => cell.passed === cell.total && cell.failed === 0));
  const orcStandards = [...new Set(cells.filter((cell) => cell.format === 'orc').map((cell) => cell.standard))];
  assert.deepEqual(orcStandards, ['ORC v1']);
  const javaOrc = cells.find((cell) => cell.language === 'java' && cell.serializer === 'orc');
  assert.equal(javaOrc.passed, 4);
  assert.equal(javaOrc.total, 4);
  const javaSbe = cells.find((cell) => cell.language === 'java' && cell.serializer === 'sbe');
  assert.equal(javaSbe.passed, 5);
  assert.equal(javaSbe.total, 5);
  assert.equal(cells.some((cell) => cell.language === 'python' && cell.format === 'sbe'), false);
  assert.ok(doc.matrix.filter((cell) => cell.format === 'json').length > 100);
  const heat = complianceHeatmap(doc.matrix, {
    format: 'orc',
    language: 'java',
    extras: [
      { language: 'java', serializer: 'orc' },
      { language: 'java', serializer: 'orc-uncompressed' },
    ],
  });
  assert.deepEqual(heat.columns.map((column) => column.standard), ['ORC v1']);
  assert.equal(heat.columns[0].unscored, undefined);
});

test('Python compliance menu files Arrow, Parquet, and ORC above No public spec', () => {
  const stats = loadJsonGz('stats_python_latest.json.gz');
  const bench = { python: benchMapFromGroups(stats.groups) };
  const ids = standardMenuOptions({ language: 'python', benchVersions: bench, matrix: [] }).map((item) => item.id);
  const noSpecAt = ids.indexOf('no-spec');
  const populated = ids.slice(0, noSpecAt);
  assert.ok(populated.includes('arrow'));
  assert.ok(populated.includes('parquet'));
  assert.ok(populated.includes('orc'));
  assert.equal(populated.includes('sbe'), false);
  const noSpec = noSpecEntries({ language: 'python', benchVersions: bench, matrix: [] }).map((e) => e.serializer);
  assert.ok(noSpec.includes('pickle'));
});
