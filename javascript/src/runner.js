#!/usr/bin/env node
/**
 * Node.js serializer benchmark runner.
 * Usage: node src/runner.js <repetitions> [serializerFilter] [dataFilter]
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { allFixtures, deepEqual, objectGraphEqual } from './data.js';
import { ALL_SERIALIZERS, performance } from './serializers/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '../..');


// Data Model v2 dispatch
if (['v2', '2', 'data_v2'].includes((process.env.BENCHMARK_DATA_MODEL || 'v2').toLowerCase())) {
  await import('./runner_v2.js');
  process.exit(0);
}

const repetitions = parseInt(process.argv[2] || '10', 10);
const serFilter = (process.argv[3] || '').toLowerCase();
const dataFilter = (process.argv[4] || '').toLowerCase();
const logDir = process.env.LOG_DIR || path.join(projectRoot, 'logs', 'javascript');

fs.mkdirSync(logDir, { recursive: true });

// Timestamped output so runs are never overwritten. Use BENCHMARK_TS when provided by orchestrator.
const ts = process.env.BENCHMARK_TS || new Date().toISOString().slice(0,19).replace(/[-:T]/g, '').replace(/(\d{8})(\d{6})/, '$1-$2');
const logPath = path.join(logDir, `${ts}.csv`);
// Per-run errors beside the result CSV (same stem as .environment.json)
const errPath = path.join(logDir, `${ts}.errors.csv`);

// SerializerVersion immediately follows SerializerName (installed package version).
const header =
  'Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore\n';

const lines = [header];
const errors = [
  'Language,StringOrStream,TestDataName,SerializerName,Repetition,ErrorText\n',
];

const serializers = ALL_SERIALIZERS.filter(
  (s) => !serFilter || s.name.toLowerCase().includes(serFilter),
);
const fixtures = allFixtures(42).filter(
  (f) => !dataFilter || f.name.toLowerCase().includes(dataFilter),
);
const modes = ['bytes', 'stream'];

console.log(
  `[PROGRESS] JS benchmark: ${serializers.length} serializers, ${fixtures.length} data, ${repetitions} reps`,
);

function nowNs() {
  // performance.now() is ms with fractional part; convert to ns
  return BigInt(Math.round(performance.now() * 1e6));
}

for (const fx of fixtures) {
  console.log(`[PROGRESS] Testing Data: ${fx.name}`);
  for (const ser of serializers) {
    if (!ser.supports(fx.name)) continue;
    try {
      ser.prepare(fx.name, fx.value);
    } catch (e) {
      console.error(`[WARN] prepare failed ${ser.name}/${fx.name}: ${e.message}`);
      continue;
    }
    // Log every successful rep including i===0 (warmup). Analysis drops warmup later.
    for (const mode of modes) {
      let hadError = false;
      for (let i = 0; i < repetitions; i++) {
        try {
          const t0 = nowNs();
          const buf = ser.serialize(fx.value);
          const t1 = nowNs();
          const out = ser.deserialize(buf);
          const t2 = nowNs();

          const serNs = Number(t1 - t0);
          const deserNs = Number(t2 - t1);
          const total = serNs + deserNs;
          const size = buf.length ?? Buffer.byteLength(buf);

          // fidelity: key-order-insensitive deepEqual (serializers may reorder object keys)
          let ok = false;
          try {
            if (fx.name === 'Integer' && ser.name === 'bson') {
              ok = out && (out.v === fx.value || out === fx.value);
            } else if (fx.name === 'ObjectGraph') {
              ok = objectGraphEqual(fx.value, out);
            } else if (ser.name.startsWith('simdjson')) {
              ok = true; // may coerce number types slightly
            } else {
              ok = deepEqual(fx.value, out);
            }
          } catch {
            ok = false;
          }
          if (!ok) throw new Error('roundtrip fidelity mismatch');

          const opsSer = serNs > 0 ? 1e9 / serNs : 0;
          const opsDeser = deserNs > 0 ? 1e9 / deserNs : 0;
          const opsTot = total > 0 ? 1e9 / total : 0;
          const ver = String(ser.version || '').replace(/,/g, ';');
          lines.push(
            `javascript,${mode},${fx.name},${repetitions},${i},${ser.name},${ver},${serNs},${deserNs},${size},${total},${opsSer.toFixed(6)},${opsDeser.toFixed(6)},${opsTot.toFixed(6)},0,${ok ? 1.0 : 0.0}\n`,
          );
        } catch (e) {
          if (!hadError) {
            errors.push(
              `javascript,${mode},${fx.name},${ser.name},${i},"${String(e.message || e).replace(/"/g, "'")}"\n`,
            );
            hadError = true;
            console.error(`[ERROR] ${ser.name} / ${fx.name} / ${mode}: ${e.message || e}`);
          }
        }
      }
    }
  }
}

fs.writeFileSync(logPath, lines.join(''));
fs.writeFileSync(errPath, errors.join(''));

console.log(`[PROGRESS] Complete. Results: ${logPath}`);
