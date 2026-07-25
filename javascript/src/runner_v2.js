#!/usr/bin/env node
/**
 * Data Model v2 runner for JavaScript.
 * Usage: BENCHMARK_DATA_MODEL=v2 node src/runner.js …
 *   or: node src/runner_v2.js <reps> [serFilter] [dataFilter]
 *
 * Default schedule is block_shuffle: prepare once per cell, then mode → rep →
 * shuffled serializers. Escape hatch: BENCHMARK_SCHEDULE=none.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { makeOne, instances } from './data_v2.js';
import { ALL_SERIALIZERS, performance } from './serializers/index.js';
import { deepEqual } from './data.js';
import {
  resolveRecordRunOrder,
  resolveScheduleStrategy,
  shuffleSerializerNames,
} from './schedule.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '../..');

const repetitions = parseInt(process.argv[2] || '10', 10);
const serFilter = (process.argv[3] || '').toLowerCase();
const dataFilter = (process.argv[4] || '').toLowerCase();
const logDirEnv = process.env.LOG_DIR || path.join(projectRoot, 'logs');
const logDir = logDirEnv.endsWith('javascript') ? logDirEnv : path.join(logDirEnv, 'javascript');
fs.mkdirSync(logDir, { recursive: true });

const ts =
  process.env.BENCHMARK_TS ||
  new Date().toISOString().slice(0, 19).replace(/[-:T]/g, '').replace(/(\d{8})(\d{6})/, '$1-$2');
const logPath = path.join(logDir, `${ts}.csv`);
const errPath = path.join(logDir, `${ts}.errors.csv`);

const header =
  'Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition\n';
const lines = [header];
const errors = ['TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n'];

function resolveRunConfig() {
  let runCfg =
    process.env.BENCHMARK_RUN_CONFIG ||
    path.join(projectRoot, 'config/library/default.yaml');
  if (!path.isAbsolute(runCfg)) {
    const fromRepo = path.join(projectRoot, runCfg.replace(/^\.\//, ''));
    runCfg = fs.existsSync(fromRepo) ? fromRepo : path.resolve(runCfg);
  }
  const seed = process.env.BENCHMARK_SEED || '42';
  const script = path.join(projectRoot, 'scripts/resolve_run_config.py');
  const r = spawnSync(
    'python3',
    [script, runCfg, '--seed', seed],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        PYTHONPATH: path.join(projectRoot, 'analysis/src'),
      },
      cwd: projectRoot,
    },
  );
  if (r.status !== 0) {
    throw new Error(`resolve_run_config failed: ${r.stderr || r.stdout}`);
  }
  return JSON.parse(r.stdout);
}

const resolved = resolveRunConfig();
const seed = Number(process.env.BENCHMARK_SEED || resolved.seed || 42);
let cells = resolved.cells || [];
if (dataFilter) {
  cells = cells.filter((c) => c.type_id.toLowerCase().includes(dataFilter));
}
// B-6: JS timed path is identical for "bytes" and "stream" labels — never claim stream.
// Until real stream APIs exist, force bytes-only regardless of resolve io_modes.
const modesRaw =
  resolved.execution?.io_modes?.length > 0 ? resolved.execution.io_modes : ['bytes'];
const modes = [...new Set(modesRaw.map((m) => String(m).toLowerCase()))].filter(
  (m) => m === 'bytes' || m === 'string' || m === 'buffer',
);
if (modes.length === 0) modes.push('bytes');
if (modesRaw.some((m) => String(m).toLowerCase() === 'stream')) {
  console.log(
    '[PROGRESS] B-6: ignoring stream io_mode for JavaScript (no distinct stream path; bytes only)',
  );
}

// Full registry — schema codecs must support v2 type_ids or skip via supports().
const serializers = ALL_SERIALIZERS.filter(
  (s) => !serFilter || s.name.toLowerCase().includes(serFilter),
);

const strategy = resolveScheduleStrategy();
const recordRO = resolveRecordRunOrder();

console.log(
  `[PROGRESS] JS Data Model v2: ${serializers.length} serializers, ${cells.length} cells, ${repetitions} reps, modes=${modes.join(',')}, schedule=${strategy}`,
);

function nowNs() {
  return BigInt(Math.round(performance.now() * 1e6));
}

let runOrder = 0;

for (const cell of cells) {
  const n = cell.data_type_instance_count || 1;
  const typeId = cell.type_id;
  const cfg = cell.type_config || {};
  const hash = cell.type_config_hash || '';
  const value = n === 1 ? makeOne(typeId, cfg, seed, 0) : instances(typeId, cfg, seed, n);
  console.log(`[PROGRESS] Cell ${typeId} N=${n}`);

  // Untimed prepare once per cell
  const prepared = [];
  const byName = new Map();
  const failed = new Set();
  for (const ser of serializers) {
    if (ser.supports && !ser.supports(typeId)) continue;
    try {
      ser.prepare?.(typeId, value);
    } catch (e) {
      errors.push(
        `${typeId},${ser.name},prepare,0,${String(e.message || e).replace(/,/g, ';')}\n`,
      );
      failed.add(ser.name);
      continue;
    }
    prepared.push(ser);
    byName.set(ser.name, ser);
  }

  for (const mode of modes) {
    for (let i = 0; i < repetitions; i++) {
      let order;
      if (strategy === 'none') {
        order = prepared.filter((s) => !failed.has(s.name));
      } else {
        const names = prepared.filter((s) => !failed.has(s.name)).map((s) => s.name);
        const shuffled = shuffleSerializerNames(names, {
          baseSeed: seed,
          typeId,
          instanceCount: n,
          typeConfigHash: hash,
          mode,
          rep: i,
        });
        order = shuffled.map((nm) => byName.get(nm)).filter(Boolean);
      }

      for (let pos = 0; pos < order.length; pos++) {
        const ser = order[pos];
        if (failed.has(ser.name)) continue;
        try {
          const t0 = nowNs();
          const buf = ser.serialize(value);
          const t1 = nowNs();
          const out = ser.deserialize(buf);
          const t2 = nowNs();
          const serNs = Number(t1 - t0);
          const deserNs = Number(t2 - t1);
          const total = serNs + deserNs;
          const size = buf.length ?? Buffer.byteLength(buf);
          if (!deepEqual(value, out)) throw new Error('roundtrip fidelity mismatch');
          const opsSer = serNs > 0 ? 1e9 / serNs : 0;
          const opsDeser = deserNs > 0 ? 1e9 / deserNs : 0;
          const opsTot = total > 0 ? 1e9 / total : 0;
          const ver = ser.version || '';
          let ro = '';
          let sp = '';
          if (recordRO) {
            ro = String(runOrder);
            sp = String(pos);
            runOrder++;
          }
          lines.push(
            [
              'javascript',
              mode,
              typeId,
              repetitions,
              i,
              ser.name,
              ver,
              serNs,
              deserNs,
              size,
              total,
              opsSer.toFixed(6),
              opsDeser.toFixed(6),
              opsTot.toFixed(6),
              0,
              '1.00',
              n,
              hash,
              ro,
              sp,
            ].join(',') + '\n',
          );
        } catch (e) {
          failed.add(ser.name);
          errors.push(
            `${typeId},${ser.name},${mode},${i},${String(e.message || e).replace(/,/g, ';').replace(/\n/g, ' ')}\n`,
          );
        }
      }
    }
  }
}

fs.writeFileSync(logPath, lines.join(''));
if (errors.length > 1) fs.writeFileSync(errPath, errors.join(''));
else if (fs.existsSync(errPath)) fs.unlinkSync(errPath);
console.log(`[PROGRESS] Complete. Results: ${logPath}`);
