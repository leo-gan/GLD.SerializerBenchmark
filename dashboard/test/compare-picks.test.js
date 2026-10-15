import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  ensureBaseline,
  hiddenPickCount,
  migrateCompareSelection,
  orderedVisible,
  resolvePickLanguages,
  seedPicks,
  visiblePicks,
} from '../compare-picks.js';

const groups = [
  { language: 'csharp', serializer: 'PureHDF' },
  { language: 'csharp', serializer: 'MemoryPack' },
  { language: 'fortran', serializer: 'hdf5-fortran' },
  { language: 'mojo', serializer: 'gld-hdf5' },
  { language: 'c', serializer: 'hdf5' },
];

test('same-language URL names the current language and stars the baseline', () => {
  const migrated = migrateCompareSelection({
    currentLanguage: 'csharp',
    urlScope: 'same',
    urlSers: ['PureHDF', 'MemoryPack'],
    urlBaseline: 'PureHDF',
  });
  assert.equal(migrated.set, true);
  assert.deepEqual(migrated.picks, [
    { lang: 'csharp', serializer: 'PureHDF' },
    { lang: 'csharp', serializer: 'MemoryPack' },
  ]);
  assert.equal(migrated.baseline, 'csharp|PureHDF');
});

test('qualified names keep their language', () => {
  const migrated = migrateCompareSelection({
    currentLanguage: 'all',
    urlSers: ['csharp|PureHDF', 'fortran|hdf5-fortran', 'mojo|gld-hdf5'],
    urlBaseline: 'csharp|PureHDF',
  });
  assert.equal(migrated.baseline, 'csharp|PureHDF');
  assert.equal(migrated.picks.length, 3);
  assert.equal(migrated.picks[2].lang, 'mojo');
});

test('scope=cross opens the cross-language list and its baseline', () => {
  const migrated = migrateCompareSelection({
    currentLanguage: 'all',
    urlScope: 'cross',
    urlSers: ['csharp|MemoryPack'],
    urlBaseline: 'csharp|MemoryPack',
    xlSelected: [
      { lang: 'csharp', serializer: 'PureHDF' },
      { lang: 'fortran', serializer: 'hdf5-fortran' },
    ],
    xlBaselineKey: 'fortran|hdf5-fortran',
    detailSerializers: ['csharp|MemoryPack'],
  });
  assert.deepEqual(
    migrated.picks.map((pick) => pick.serializer),
    ['PureHDF', 'hdf5-fortran'],
  );
  assert.equal(migrated.baseline, 'fortran|hdf5-fortran');
});

test('a saved list, including an empty one, is not refilled from legacy names', () => {
  const empty = migrateCompareSelection({
    comparePicksPresent: true,
    comparePicks: [],
    detailSerializers: ['PureHDF', 'MemoryPack'],
    currentLanguage: 'csharp',
    scope: 'same',
  });
  assert.equal(empty.set, true);
  assert.deepEqual(empty.picks, []);
  assert.equal(empty.baseline, '');

  const kept = migrateCompareSelection({
    comparePicksPresent: true,
    comparePicks: [{ lang: 'mojo', serializer: 'gld-hdf5' }],
    comparePickBaseline: 'mojo|gld-hdf5',
    detailSerializers: ['csharp|PureHDF'],
    xlSelected: [{ lang: 'c', serializer: 'hdf5' }],
    urlScope: 'cross',
  });
  assert.deepEqual(kept.picks, [{ lang: 'mojo', serializer: 'gld-hdf5' }]);
  assert.equal(kept.baseline, 'mojo|gld-hdf5');
});

test('URL ser wins over a saved list when the link is not cross-language', () => {
  const migrated = migrateCompareSelection({
    comparePicksPresent: true,
    comparePicks: [{ lang: 'mojo', serializer: 'gld-hdf5' }],
    urlSers: ['csharp|PureHDF'],
    urlCbase: 'csharp|PureHDF',
    currentLanguage: 'all',
  });
  assert.deepEqual(migrated.picks, [{ lang: 'csharp', serializer: 'PureHDF' }]);
  assert.equal(migrated.baseline, 'csharp|PureHDF');
});

test('nothing saved leaves the list unset so the page can seed it', () => {
  const migrated = migrateCompareSelection({ currentLanguage: 'python' });
  assert.equal(migrated.set, false);
  assert.deepEqual(migrated.picks, []);
});

test('migration caps at 8 and drops duplicates', () => {
  const names = ['a', 'b', 'a', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];
  const migrated = migrateCompareSelection({
    currentLanguage: 'rust',
    detailSerializers: names,
  });
  assert.equal(migrated.picks.length, 8);
  assert.deepEqual(
    migrated.picks.map((pick) => pick.serializer),
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
  );
  assert.equal(migrated.baseline, 'rust|a');
});

test('a filter hides picks without deleting them', () => {
  const picks = [
    { lang: 'csharp', serializer: 'PureHDF' },
    { lang: 'fortran', serializer: 'hdf5-fortran' },
    { lang: 'mojo', serializer: 'gld-hdf5' },
  ];
  const csharpOnly = groups.filter((g) => g.language === 'csharp');
  assert.deepEqual(
    visiblePicks(picks, csharpOnly).map((pick) => pick.serializer),
    ['PureHDF'],
  );
  assert.equal(hiddenPickCount(picks, csharpOnly), 2);
  assert.equal(visiblePicks(picks, groups).length, 3);
});

test('the baseline column is first and the other chips keep their order', () => {
  const picks = [
    { lang: 'csharp', serializer: 'PureHDF' },
    { lang: 'fortran', serializer: 'hdf5-fortran' },
    { lang: 'mojo', serializer: 'gld-hdf5' },
  ];
  const ordered = orderedVisible(picks, groups, 'mojo|gld-hdf5');
  assert.deepEqual(
    ordered.map((pick) => pick.serializer),
    ['gld-hdf5', 'PureHDF', 'hdf5-fortran'],
  );
  const hiddenBase = orderedVisible(picks, groups.filter((g) => g.language !== 'mojo'), 'mojo|gld-hdf5');
  assert.deepEqual(
    hiddenBase.map((pick) => pick.serializer),
    ['PureHDF', 'hdf5-fortran'],
  );
});

test('bare names resolve only when the language is unambiguous', () => {
  const resolved = resolvePickLanguages(
    [{ lang: '', serializer: 'hdf5-fortran' }, { lang: '', serializer: 'PureHDF' }, { lang: '', serializer: 'hdf5' }],
    groups,
    'all',
  );
  assert.equal(resolved[0].lang, 'fortran');
  assert.equal(resolved[1].lang, 'csharp');
  assert.equal(resolved[2].lang, 'c');

  const ambiguous = resolvePickLanguages(
    [{ lang: '', serializer: 'shared' }],
    [
      { language: 'python', serializer: 'shared' },
      { language: 'rust', serializer: 'shared' },
    ],
    'all',
  );
  assert.equal(ambiguous[0].lang, '');

  const onPython = resolvePickLanguages([{ lang: '', serializer: 'orjson' }], [], 'python');
  assert.deepEqual(onPython, [{ lang: 'python', serializer: 'orjson' }]);
});

test('ensureBaseline keeps a hidden star and falls back when the star is gone', () => {
  const picks = [
    { lang: 'fortran', serializer: 'hdf5-fortran' },
    { lang: 'mojo', serializer: 'gld-hdf5' },
  ];
  assert.equal(ensureBaseline(picks, 'mojo|gld-hdf5'), 'mojo|gld-hdf5');
  assert.equal(ensureBaseline(picks, 'csharp|PureHDF'), 'fortran|hdf5-fortran');
  assert.equal(ensureBaseline(picks, 'gld-hdf5'), 'mojo|gld-hdf5');
});

test('seed keeps the given order and stars the first', () => {
  const seeded = seedPicks(groups, 6);
  assert.equal(seeded.picks.length, 5);
  assert.equal(seeded.baseline, 'csharp|PureHDF');
  assert.equal(seedPicks([], 6).set, false);
});
