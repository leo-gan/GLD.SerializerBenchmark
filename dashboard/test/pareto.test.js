import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isParetoDominated, paretoOptimalGroups } from '../pareto.js';

// all@all bytes, C#, IQR 1.5. Mean ops/sec is not 1/mean latency, so the
// latency chart must not reuse the ops frontier.
const zeroFormatter = {
  serializer: 'ZeroFormatter',
  avg_ops_per_sec: 48290.8,
  avg_time_total_ns: 82618.56,
  median_size_bytes: 15588.4,
};
const binaryPack = {
  serializer: 'BinaryPack',
  avg_ops_per_sec: 75248.5,
  avg_time_total_ns: 94259.98,
  median_size_bytes: 15832.0,
};
const bondCompact = {
  serializer: 'MS Bond Compact',
  avg_ops_per_sec: 66818.3,
  avg_time_total_ns: 87547.71,
  median_size_bytes: 13039.2,
};
const csv = {
  serializer: 'CsvHelper',
  avg_ops_per_sec: 469.5,
  avg_time_total_ns: 2916600,
  median_size_bytes: 8816,
};
const groups = [zeroFormatter, binaryPack, bondCompact, csv];

test('latency Pareto keeps the faster and smaller library', () => {
  assert.equal(isParetoDominated(zeroFormatter, groups, 'time'), false);
  assert.equal(isParetoDominated(binaryPack, groups, 'time'), true);
  assert.deepEqual(
    paretoOptimalGroups(groups, 'time').map((g) => g.serializer),
    ['ZeroFormatter', 'MS Bond Compact', 'CsvHelper'],
  );
});

test('ops Pareto follows mean ops/sec, which can disagree with mean latency', () => {
  assert.equal(isParetoDominated(binaryPack, groups, 'ops'), false);
  assert.equal(isParetoDominated(zeroFormatter, groups, 'ops'), true);
  assert.deepEqual(
    paretoOptimalGroups(groups, 'ops').map((g) => g.serializer),
    ['BinaryPack', 'MS Bond Compact', 'CsvHelper'],
  );
});
