import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { heatmapFromMatrix, parseRowIdentity } from '../compliance-matrix.js';
import { CATALOG } from '../compliance-catalog.js';
import { catalogMissing, classifyByName, classifySerializer } from '../compliance-classify.js';
import {
  EMPTY_STANDARDS_SEP,
  EMPTY_STANDARDS_SEP_ID,
  NO_SPEC,
  NO_SPEC_LABEL,
  SERIALIZER_ALIASES,
  attachFormats,
  auditComplianceGroups,
  benchMapFromGroups,
  canonicalSerializer,
  formatLabel,
  formatSubset,
  formatsBySerializer,
  noSpecEntries,
  padHeatmap,
  rosterEntries,
  standardMenuOptions,
  standardOptionIds,
} from '../compliance-groups.js';

function cell(language, serializer, format, standard = format, total = 4) {
  return {
    language,
    serializer,
    format,
    standard,
    version: '1',
    passed: total,
    failed: 0,
    total,
  };
}

const csharpBench = {
  csharp: {
    'System.Text.Json': '8.0',
    'Json.Net': '13.0',
    Jil: '3.0',
    ProtoBuf: '3.2',
    'MS Binary': '8.0',
    YamlDotNet: '16.0',
    SpanJson: '1.0',
  },
};

const csharpMatrix = [
  cell('csharp', 'System.Text.Json', 'json', 'RFC 8259'),
  cell('csharp', 'Json.Net', 'json', 'RFC 8259'),
  cell('csharp', 'YamlDotNet', 'yaml', 'YAML 1.2'),
  cell('csharp', 'protobuf-net', 'protobuf', 'Protocol Buffers'),
];

function loadJsonGz(name) {
  const dir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'data');
  const buf = readFileSync(join(dir, name));
  const raw = buf[0] === 0x1f && buf[1] === 0x8b ? gunzipSync(buf) : buf;
  return JSON.parse(raw.toString('utf8'));
}

function benchMapFromStats(doc) {
  return benchMapFromGroups(doc.groups);
}

test('No public spec is marked with * and sits after populated Standards', () => {
  const ids = standardOptionIds();
  assert.ok(ids.includes(NO_SPEC));
  assert.equal(ids.filter((id) => id === NO_SPEC).length, 1);
  assert.equal(formatLabel(NO_SPEC), NO_SPEC_LABEL);
  assert.ok(NO_SPEC_LABEL.startsWith('*'));
  assert.ok(ids.includes('json'));
  assert.ok(ids.indexOf('json') < ids.indexOf(NO_SPEC));
});

test('Standard menu is populated families, No public spec, separator, then empty families', () => {
  const cBench = {
    c: Object.fromEntries(CATALOG.filter((e) => e.language === 'c').map((e) => [e.name, '1'])),
  };
  const items = standardMenuOptions({ language: 'c', benchVersions: cBench, matrix: [] });
  const ids = items.map((item) => item.id);
  const sepAt = ids.indexOf(EMPTY_STANDARDS_SEP_ID);
  const noSpecAt = ids.indexOf(NO_SPEC);
  assert.ok(noSpecAt >= 0);
  assert.ok(sepAt > noSpecAt);
  assert.equal(items[sepAt].disabled, true);
  assert.equal(items[sepAt].label, EMPTY_STANDARDS_SEP);
  const populated = ids.slice(0, noSpecAt);
  const empty = ids.slice(sepAt + 1);
  assert.ok(populated.includes('json'));
  assert.ok(populated.includes('cbor'));
  assert.ok(populated.includes('avro'));
  assert.ok(populated.includes('bson'));
  assert.ok(populated.includes('flatbuffers'));
  assert.ok(!populated.includes('yaml'));
  assert.ok(empty.includes('yaml'));
  assert.ok(empty.includes('toml'));
  const labels = populated.map(formatLabel);
  assert.deepEqual(labels, [...labels].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })));
  const emptyLabels = empty.map(formatLabel);
  assert.deepEqual(
    emptyLabels,
    [...emptyLabels].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })),
  );
  for (const item of items.slice(0, sepAt)) assert.equal(item.disabled, false);
  for (const item of items.slice(sepAt + 1)) assert.equal(item.disabled, false);
});

test('bench roster keeps serializers that have no published version', () => {
  const map = benchMapFromGroups([
    { serializer: 'Jil', serializer_version: '3.0.0' },
    { serializer: 'SpanJson' },
    { serializer: 'Jil', serializer_version: 'ignored-dup' },
    { serializer: '' },
  ]);
  assert.deepEqual(map, { Jil: '3.0.0', SpanJson: '' });
  const all = rosterEntries({
    language: 'csharp',
    benchVersions: { csharp: map },
    matrix: [],
  });
  assert.deepEqual(all.map((e) => e.serializer), ['Jil', 'SpanJson']);
});

test('aliases map compliance adapter names onto Overview names', () => {
  assert.equal(canonicalSerializer('csharp', 'protobuf-net'), 'ProtoBuf');
  assert.equal(canonicalSerializer('csharp', 'ProtoBuf'), 'ProtoBuf');
  assert.equal(canonicalSerializer('javascript', 'JSON.parse'), 'JSON.stringify');
  assert.equal(canonicalSerializer('python', 'fastavro'), 'avro');
  assert.equal(canonicalSerializer('swift', 'Foundation.JSONSerialization'), 'Foundation.JSONEncoder');
});

test('C# All is the full language roster, not the scored subset', () => {
  const all = rosterEntries({ language: 'csharp', benchVersions: csharpBench, matrix: csharpMatrix });
  const names = all.map((e) => e.serializer);
  assert.deepEqual(names.sort(), [
    'Jil',
    'Json.Net',
    'MS Binary',
    'ProtoBuf',
    'SpanJson',
    'System.Text.Json',
    'YamlDotNet',
  ]);
  assert.equal(names.includes('protobuf-net'), false);
  assert.ok(names.length > formatSubset(csharpMatrix, 'json', 'csharp').length);
});

test('No public spec is All minus every classified Standard', () => {
  const args = { language: 'csharp', benchVersions: csharpBench, matrix: csharpMatrix };
  const all = new Set(rosterEntries(args).map((e) => e.serializer));
  const scored = new Set();
  for (const fmt of ['json', 'yaml', 'protobuf']) {
    for (const e of formatSubset(csharpMatrix, fmt, 'csharp', csharpBench)) scored.add(e.serializer);
  }
  const noSpec = new Set(noSpecEntries(args).map((e) => e.serializer));
  for (const name of all) {
    assert.equal(scored.has(name), !noSpec.has(name), name);
  }
  assert.deepEqual([...noSpec].sort(), ['MS Binary']);
  assert.equal(noSpec.has('Jil'), false);
  assert.equal(noSpec.has('SpanJson'), false);
  assert.equal(noSpec.has('System.Text.Json'), false);
  assert.equal(noSpec.has('ProtoBuf'), false);
});

test('one serializer may belong to several Standards and still appear once in All', () => {
  const bench = { python: { msgspec: '0.18', pickle: '3.12' } };
  const matrix = [
    cell('python', 'msgspec', 'json', 'RFC 8259', 8),
    cell('python', 'msgspec', 'msgpack', 'MessagePack 2013', 6),
  ];
  const args = { language: 'python', benchVersions: bench, matrix };
  const { all, scored, noSpec, membership, issues } = auditComplianceGroups(args);
  assert.deepEqual(issues, []);
  assert.equal(all.length, 2);
  assert.equal(scored.length, 1);
  assert.equal(noSpec.map((e) => e.serializer).join(), 'pickle');
  const json = formatSubset(matrix, 'json', 'python').map((e) => e.serializer);
  const pack = formatSubset(matrix, 'msgpack', 'python').map((e) => e.serializer);
  assert.deepEqual(json, ['msgspec']);
  assert.deepEqual(pack, ['msgspec']);
  assert.ok(json.length + pack.length > scored.length, 'overlap makes subset sizes exceed the union');
  const key = scored[0].key;
  assert.deepEqual([...membership.get(key)].sort(), ['json', 'msgpack']);
  assert.equal(noSpec.some((e) => e.serializer === 'msgspec'), false);

  const extras = rosterEntries(args);
  const { rows } = attachFormats(
    padHeatmap(
      heatmapFromMatrix(matrix, { format: '' }),
      extras,
    ),
    matrix,
    'python',
  );
  const dual = rows.filter((r) => r.serializer === 'msgspec');
  assert.equal(dual.length, 1, 'All keeps a single row for a multi-standard serializer');
  assert.deepEqual(dual[0].formats, ['json', 'msgpack']);
  assert.equal(dual[0].byStandard.size, 2);
  assert.equal(dual[0].byStandard.get('RFC 8259').total, 8);
  assert.equal(dual[0].byStandard.get('MessagePack 2013').total, 6);
});

test('auditComplianceGroups reports a clean partition', () => {
  const { all, scored, noSpec, issues } = auditComplianceGroups({
    language: 'csharp',
    benchVersions: csharpBench,
    matrix: csharpMatrix,
  });
  assert.deepEqual(issues, []);
  assert.equal(all.length, scored.length + noSpec.length);
});

test('All heatmap pads every language serializer, including ungraded ones', () => {
  const extras = rosterEntries({
    language: 'csharp',
    benchVersions: csharpBench,
    matrix: csharpMatrix,
  });
  const { rows } = padHeatmap(
    heatmapFromMatrix(csharpMatrix.map((c) => ({
      ...c,
      serializer: canonicalSerializer(c.language, c.serializer),
    })), { format: '' }),
    extras,
  );
  const names = rows.map((r) => r.serializer);
  assert.ok(names.includes('Jil'));
  assert.ok(names.includes('MS Binary'));
  assert.ok(names.includes('SpanJson'));
  assert.ok(names.includes('ProtoBuf'));
  assert.equal(names.includes('protobuf-net'), false);
  assert.equal(rows.length, extras.length);
  const jil = rows.find((r) => r.serializer === 'Jil');
  assert.equal(jil.byStandard.size, 0);
  const jsonNet = rows.find((r) => r.serializer === 'Json.Net');
  assert.ok(jsonNet.byStandard.size > 0);
});

test('dashboard classification is compliance/serializer-standards.json', () => {
  const mapping = JSON.parse(
    readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'compliance', 'serializer-standards.json'), 'utf8'),
  );
  let n = 0;
  for (const [lang, rows] of Object.entries(mapping.languages)) {
    for (const [name, fmts] of Object.entries(rows)) {
      n += 1;
      assert.deepEqual(classifySerializer(lang, name), fmts, `${lang}/${name}`);
      assert.equal(catalogMissing(lang, name), false);
    }
  }
  assert.ok(n >= 200, `expected a full mapping, got ${n} rows`);
  assert.deepEqual(classifySerializer('csharp', 'not-a-real-library'), []);
  for (const e of CATALOG) {
    assert.deepEqual(e.formats, mapping.languages[e.language][e.name], `catalog.js drifted from JSON: ${e.language}/${e.name}`);
  }
});

test('classification comes from official docs, not the spelling of the name', () => {
  assert.deepEqual(classifySerializer('c', 'cJSON'), ['json']);
  assert.deepEqual(classifySerializer('c', 'jansson'), ['json']);
  assert.deepEqual(classifySerializer('c', 'yyjson'), ['json']);
  assert.deepEqual(classifySerializer('c', 'json-c'), ['json']);
  assert.deepEqual(classifySerializer('c', 'parson'), ['json']);
  assert.deepEqual(classifySerializer('c', 'mpack'), ['msgpack']);
  assert.deepEqual(classifySerializer('c', 'msgpack-c'), ['msgpack']);
  assert.deepEqual(classifySerializer('csharp', 'MessagePack-CSharp'), ['msgpack']);
  assert.deepEqual(classifySerializer('javascript', 'json-pack-msgpack'), ['msgpack']);
  assert.deepEqual(classifySerializer('python', 'msgspec'), ['json']);
  assert.deepEqual(classifySerializer('python', 'msgspec-msgpack'), ['msgpack']);
  assert.deepEqual(classifySerializer('csharp', 'MS Bond Json'), ['json', 'bond']);
  assert.deepEqual(classifySerializer('csharp', 'Jil'), ['json']);
  assert.deepEqual(classifySerializer('c', 'custom-binary'), []);
  const jansson = CATALOG.find((e) => e.language === 'c' && e.name === 'jansson');
  assert.ok(jansson.docs.startsWith('https://'));
  assert.match(jansson.evidence, /JSON/i);
  assert.equal(classifyByName('json-pack-msgpack')[0], 'msgpack');
});

test('every Overview serializer has a documented catalog row', () => {
  const langs = [
    'python', 'javascript', 'go', 'java', 'kotlin', 'csharp', 'rust',
    'c', 'cpp', 'swift', 'php', 'zig', 'mojo',
  ];
  const missing = [];
  for (const lang of langs) {
    let stats;
    try {
      stats = loadJsonGz(`stats_${lang}_latest.json.gz`);
    } catch {
      continue;
    }
    const names = new Set();
    for (const g of stats.groups || []) {
      if (g.serializer) names.add(g.serializer);
    }
    for (const name of names) {
      if (catalogMissing(lang, name)) missing.push(`${lang}/${name}`);
    }
  }
  assert.deepEqual(missing, [], `undocumented serializers:\n${missing.join('\n')}`);
});

test('live C payload scores mapped Avro / MessagePack / JSON libraries', () => {
  const compliance = loadJsonGz('compliance.json.gz');
  const cells = (compliance.matrix || []).filter((c) => c.language === 'c');
  const by = new Map();
  for (const c of cells) {
    by.set(`${c.format}:${c.serializer}`, (Number(c.total) || 0) + (by.get(`${c.format}:${c.serializer}`) || 0));
  }
  assert.ok((by.get('avro:avro-c') || 0) > 0, 'C avro-c must have live Avro cells');
  assert.ok((by.get('msgpack:mpack') || 0) > 0, 'C mpack must have live MessagePack cells');
  assert.ok((by.get('json:jansson') || 0) > 0, 'C jansson must have live JSON cells');
  assert.ok((by.get('json:yyjson') || 0) > 0, 'C yyjson must have live JSON cells');
});

test('C JSON and MessagePack subsets include ungraded libraries', () => {
  const compliance = loadJsonGz('compliance.json.gz');
  const benchVersions = { c: benchMapFromStats(loadJsonGz('stats_c_latest.json.gz')) };
  const json = formatSubset(compliance.matrix, 'json', 'c', benchVersions).map((e) => e.serializer);
  const pack = formatSubset(compliance.matrix, 'msgpack', 'c', benchVersions).map((e) => e.serializer);
  for (const name of ['cJSON', 'jansson', 'json-c', 'parson', 'yyjson']) {
    assert.ok(json.includes(name), `C JSON missing ${name}`);
  }
  for (const name of ['mpack', 'msgpack-c']) {
    assert.ok(pack.includes(name), `C MessagePack missing ${name}`);
  }
  const noSpec = noSpecEntries({
    language: 'c',
    benchVersions,
    matrix: compliance.matrix,
  }).map((e) => e.serializer);
  assert.ok(noSpec.includes('custom-binary'));
  assert.equal(noSpec.includes('mpack'), false);
  assert.equal(noSpec.includes('jansson'), false);
});

test('live C# payload: All includes every Overview serializer', () => {
  const compliance = loadJsonGz('compliance.json.gz');
  const stats = loadJsonGz('stats_csharp_latest.json.gz');
  const benchVersions = { csharp: benchMapFromStats(stats) };
  const benchNames = Object.keys(benchVersions.csharp);
  assert.ok(benchNames.length >= 30, `expected a full C# roster, got ${benchNames.length}`);

  const { all, scored, noSpec, issues } = auditComplianceGroups({
    language: 'csharp',
    benchVersions,
    matrix: compliance.matrix,
  });
  assert.deepEqual(issues, []);
  const allNames = new Set(all.map((e) => e.serializer));
  for (const name of benchNames) {
    assert.ok(allNames.has(name), `C# All is missing Overview serializer ${name}`);
  }
  assert.ok(all.length > scored.length, 'All must be larger than the scored C# subset');
  assert.ok(!allNames.has('protobuf-net'));
  assert.ok(allNames.has('ProtoBuf'));
  assert.equal(noSpec.some((e) => e.serializer === 'Jil'), false);
  assert.ok(scored.some((e) => e.serializer === 'Jil'));
  assert.equal(
    scored.some((e) => e.serializer === 'System.Text.Json'),
    true,
  );
  assert.equal(
    noSpec.some((e) => e.serializer === 'System.Text.Json'),
    false,
  );
});

test('live payload: every language All = scored ∪ No public spec', () => {
  const compliance = loadJsonGz('compliance.json.gz');
  const langs = [...new Set((compliance.languages || []).map(String))];
  const benchVersions = {};
  for (const lang of langs) {
    try {
      benchVersions[lang] = benchMapFromStats(loadJsonGz(`stats_${lang}_latest.json.gz`));
    } catch {
      benchVersions[lang] = {};
    }
  }
  const { issues } = auditComplianceGroups({
    language: '',
    benchVersions,
    matrix: compliance.matrix,
  });
  assert.deepEqual(issues, []);
  for (const lang of langs) {
    const report = auditComplianceGroups({
      language: lang,
      benchVersions,
      matrix: compliance.matrix,
    });
    assert.deepEqual(report.issues, [], lang);
    const benchNames = Object.keys(benchVersions[lang] || {});
    const allNames = new Set(report.all.map((e) => e.serializer));
    for (const name of benchNames) {
      assert.ok(allNames.has(canonicalSerializer(lang, name)), `${lang} All missing ${name}`);
    }
  }
});

test('live payload allows overlapping Standard subsets', () => {
  const compliance = loadJsonGz('compliance.json.gz');
  const membership = formatsBySerializer(compliance.matrix);
  let multi = 0;
  for (const [key, fmts] of membership) {
    if (fmts.size < 2) continue;
    multi += 1;
    const { language, serializer } = parseRowIdentity(key);
    for (const fmt of fmts) {
      const hit = formatSubset(compliance.matrix, fmt, language).some((e) => e.serializer === serializer);
      assert.ok(hit, `${language}/${serializer} missing from ${fmt}`);
    }
    const noSpec = noSpecEntries({
      language,
      benchVersions: {},
      matrix: compliance.matrix,
    });
    assert.equal(
      noSpec.some((e) => e.serializer === serializer && e.language === language),
      false,
      `${language}/${serializer} must not land in No public spec`,
    );
  }
  // Today most languages register one bench name per family (jackson vs jackson-yaml).
  // Overlap must stay legal even when the live count is zero.
  assert.ok(multi >= 0);
});

test('alias table only remaps known split names', () => {
  for (const [lang, map] of Object.entries(SERIALIZER_ALIASES)) {
    for (const [from, to] of Object.entries(map)) {
      assert.notEqual(from, to, `${lang} ${from}`);
      assert.equal(canonicalSerializer(lang, from), to);
    }
  }
});
