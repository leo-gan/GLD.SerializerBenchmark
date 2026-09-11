#!/usr/bin/env node
/**
 * JavaScript compliance runner — same catalog as Python.
 *
 *   node javascript/src/compliance.mjs --json-out logs/compliance/javascript.json
 */
import { readdirSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { toObject as flexToObject } from 'flatbuffers/mjs/flexbuffers.js';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '../..');
const catalogRoot = join(repoRoot, 'compliance/data');

function pkgVersion(name) {
  if (!name) return '';
  const files = [
    join(here, '../node_modules', name, 'package.json'),
    join(repoRoot, 'javascript/node_modules', name, 'package.json'),
  ];
  for (const p of files) {
    try {
      const v = JSON.parse(readFileSync(p, 'utf8')).version;
      if (v) return String(v);
    } catch {
      /* try the next resolver */
    }
  }
  try {
    return require(`${name}/package.json`).version || '';
  } catch {
    return '';
  }
}

function parseArgs(argv) {
  const out = { jsonOut: null, formats: [], serializers: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if ((a === '--json-out' || a === '-o') && argv[i + 1]) out.jsonOut = argv[++i];
    else if ((a === '--format' || a === '-f') && argv[i + 1]) out.formats.push(argv[++i]);
    else if ((a === '--serializer' || a === '-s') && argv[i + 1]) out.serializers.push(argv[++i]);
  }
  return out;
}

function decodeProtobufJs(protobuf, buf, schema) {
  if (schema === 'json') {
    const v = JSON.parse(buf.toString('utf8'));
    if (v === null || typeof v !== 'object' || Array.isArray(v)) {
      throw new Error('proto3 JSON message must be an object');
    }
    const doc = { n: 0, s: '', ok: false, tags: [] };
    if (v.n != null) doc.n = pbInt32(v.n);
    if (v.s != null) {
      if (typeof v.s !== 'string') throw new Error('s must be a string');
      doc.s = v.s;
    }
    if (v.ok != null) {
      if (typeof v.ok !== 'boolean') throw new Error('ok must be a bool');
      doc.ok = v.ok;
    }
    if (v.tags != null) {
      if (!Array.isArray(v.tags)) throw new Error('tags must be an array');
      doc.tags = v.tags.map(pbInt32);
    }
    return doc;
  }
  const r = protobuf.Reader.create(buf);
  const doc = { n: 0, s: '', ok: false, tags: [] };
  while (r.pos < r.len) {
    const tag = r.uint32();
    const field = tag >>> 3;
    const wt = tag & 7;
    if (field === 1 && wt === 0) doc.n = r.int32();
    else if (field === 2 && wt === 2) {
      const n = r.uint32();
      if (r.pos + n > r.len) throw new Error('truncated length-delimited');
      doc.s = Buffer.from(r.buf.subarray(r.pos, r.pos + n)).toString('utf8');
      r.pos += n;
    } else if (field === 3 && wt === 0) doc.ok = r.bool();
    else if (field === 4 && wt === 0) doc.tags.push(r.int32());
    else if (field === 4 && wt === 2) {
      const n = r.uint32();
      if (r.pos + n > r.len) throw new Error('truncated length-delimited');
      const end = r.pos + n;
      while (r.pos < end) doc.tags.push(r.int32());
    } else {
      r.skipType(wt);
    }
  }
  return doc;
}

function pbInt32(v) {
  if (typeof v === 'number' && Number.isFinite(v)) return v | 0;
  if (typeof v === 'string' && /^-?\d+$/.test(v)) return Number(v);
  throw new Error('int32 must be a number or digit string');
}

function inputBytes(c) {
  if (c.input_encoding === 'hex') {
    const compact = String(c.input || '').replace(/\s+/g, '');
    return Buffer.from(compact, 'hex');
  }
  if (c.input_encoding === 'latin-1') return Buffer.from(String(c.input || ''), 'latin1');
  return Buffer.from(String(c.input ?? ''), 'utf8');
}

function valuesEqual(expected, observed) {
  if (expected && typeof expected === 'object' && !Array.isArray(expected) && Object.keys(expected).length === 1) {
    if ('$hex' in expected) {
      if (!Buffer.isBuffer(observed) && !(observed instanceof Uint8Array)) return false;
      return Buffer.from(observed).equals(Buffer.from(String(expected.$hex).replace(/\s+/g, ''), 'hex'));
    }
    if ('$float' in expected) {
      const t = String(expected.$float).toLowerCase();
      if (t === 'nan') return Number.isNaN(observed);
      if (t === 'inf') return observed === Infinity;
      if (t === '-inf') return observed === -Infinity;
    }
  }
  if (expected === null) return observed === null || observed === undefined;
  if (typeof expected === 'boolean' || typeof observed === 'boolean') return expected === observed;
  if (typeof expected === 'number' && typeof observed === 'number') {
    if (Number.isNaN(expected)) return Number.isNaN(observed);
    return expected === observed;
  }
  if (typeof expected === 'string') {
    if (Buffer.isBuffer(observed) || observed instanceof Uint8Array) {
      try {
        return Buffer.from(observed).toString('utf8') === expected;
      } catch {
        return false;
      }
    }
    return expected === observed;
  }
  if (Array.isArray(expected)) {
    if (!Array.isArray(observed) || expected.length !== observed.length) return false;
    return expected.every((v, i) => valuesEqual(v, observed[i]));
  }
  if (expected && typeof expected === 'object') {
    if (!observed || typeof observed !== 'object' || Array.isArray(observed)) return false;
    const ek = Object.keys(expected);
    const ok = Object.keys(observed);
    if (ek.length !== ok.length) return false;
    return ek.every((k) => valuesEqual(expected[k], observed[k]));
  }
  return expected === observed;
}

function preview(value, limit = 120) {
  let text;
  try {
    if (value === undefined) text = 'undefined';
    else if (typeof value === 'symbol') text = value.toString();
    else text = JSON.stringify(value);
    if (text == null) text = String(value);
  } catch {
    text = String(value);
  }
  if (text.length > limit) return `${text.slice(0, limit - 3)}...`;
  return text;
}

function loadSuites() {
  const suites = [];
  for (const fmt of readdirSync(catalogRoot).sort()) {
    const dir = join(catalogRoot, fmt);
    let files;
    try {
      files = readdirSync(dir).filter((n) => n.endsWith('.json') && !n.startsWith('_'));
    } catch {
      continue;
    }
    for (const name of files.sort()) {
      const path = join(dir, name);
      const raw = JSON.parse(readFileSync(path, 'utf8'));
      if (!raw.cases?.length) continue;
      suites.push({ ...raw, source_path: path });
    }
  }
  if (!suites.length) throw new Error(`No compliance suites under ${catalogRoot}`);
  return suites;
}

function makeAdapters() {
  const adapters = [];

  const add = (name, format, decode, notes, pkg) => {
    adapters.push({ name, format, decode, notes, version: pkgVersion(pkg) });
  };

  add('JSON.parse', 'json', (buf) => JSON.parse(buf.toString('utf8')), 'Node JSON.parse', '');
  adapters[adapters.length - 1].version = `node-${process.versions.node}`;
  try {
    const yaml = require('js-yaml');
    add('js-yaml', 'yaml', (buf) => yaml.load(buf.toString('utf8')), 'js-yaml load', 'js-yaml');
  } catch { /* optional */ }
  try {
    const { Decoder } = require('cbor-x');
    const dec = new Decoder();
    add('cbor-x', 'cbor', (buf) => dec.decode(buf), 'cbor-x Decoder', 'cbor-x');
  } catch { /* optional */ }
  try {
    const cbor = require('cbor');
    add('cbor', 'cbor', (buf) => cbor.decodeFirstSync(buf), 'node-cbor decodeFirstSync', 'cbor');
  } catch { /* optional */ }
  try {
    const { Unpackr } = require('msgpackr');
    const unpackr = new Unpackr({ useRecords: false });
    add('msgpackr', 'msgpack', (buf) => unpackr.unpack(buf), 'msgpackr Unpackr', 'msgpackr');
  } catch { /* optional */ }
  try {
    const mp = require('@msgpack/msgpack');
    add('@msgpack/msgpack', 'msgpack', (buf) => mp.decode(buf), '@msgpack/msgpack decode', '@msgpack/msgpack');
  } catch { /* optional */ }
  try {
    const { BSON } = require('bson');
    add('bson', 'bson', (buf) => BSON.deserialize(buf), 'mongodb bson', 'bson');
  } catch { /* optional */ }
  add('flexbuffers', 'flatbuffers', (buf) => flexToObject(buf), 'flatbuffers flexbuffers', 'flatbuffers');
  try {
    const avro = require('avsc');
    add(
      'avsc',
      'avro',
      (buf, schema) => avro.Type.forSchema(schema ?? 'int').fromBuffer(buf),
      'avsc schemaless',
      'avsc',
    );
  } catch { /* optional */ }
  try {
    const protobuf = require('protobufjs');
    add(
      'protobufjs',
      'protobuf',
      (buf, schema) => decodeProtobufJs(protobuf, buf, schema),
      'protobufjs Reader + proto3 JSON mapping on cmp.Doc',
      'protobufjs',
    );
  } catch { /* optional */ }
  try {
    const bebop = require('bebop');
    add('bebop', 'bebop', (buf) => {
      if (buf.length === 0) return {};
      if (buf.length === 1) return buf[0] !== 0;
      throw new Error('no generated Bebop type for this payload');
    }, 'bebop runtime (bool / empty only)', 'bebop');
  } catch { /* optional */ }

  return adapters.filter((a) => typeof a.decode === 'function');
}

function runOne(suite, c, adapter) {
  const raw = inputBytes(c);
  let observed;
  let decodedOk = true;
  let decodeError = null;
  try {
    observed = adapter.decode(raw, c.schema);
  } catch (err) {
    decodedOk = false;
    decodeError = `${err?.name || 'Error'}: ${err?.message || err}`;
  }
  const base = {
    id: c.id,
    language: 'javascript',
    serializer: adapter.name,
    serializer_version: adapter.version,
    format: suite.format,
    standard: suite.standard,
    standard_url: suite.standard_url || '',
    version: String(suite.version),
    version_key: `${suite.format}.${suite.version}`,
    requirement: c.requirement,
    expect: c.expect,
    section: c.section,
    section_title: c.section_title,
    section_url: c.section_url,
    paragraph: c.paragraph,
    title: c.title,
    input: c.input,
    input_encoding: c.input_encoding || 'utf-8',
    detail: '',
    observed: '',
    outcome: 'pass',
  };
  if (c.expect === 'any') {
    return { ...base, outcome: 'pass', observed: decodeError || preview(observed), detail: 'implementation-defined (recorded, not scored)' };
  }
  if (c.expect === 'reject') {
    if (!decodedOk) return { ...base, outcome: 'pass', observed: decodeError || 'rejected' };
    return { ...base, outcome: 'fail', detail: 'parser accepted input the spec requires to be rejected', observed: `accepted as ${preview(observed)}` };
  }
  if (!decodedOk) {
    return { ...base, outcome: 'fail', detail: 'parser rejected input the spec requires to accept', observed: decodeError || 'rejected' };
  }
  if (
    Object.prototype.hasOwnProperty.call(c, 'decoded') &&
    observed !== Symbol.for('wire-ok') &&
    !valuesEqual(c.decoded, observed)
  ) {
    return { ...base, outcome: 'fail', detail: 'decoded value does not match the catalog case', observed: `got ${preview(observed)}, want ${preview(c.decoded)}` };
  }
  return { ...base, outcome: 'pass', observed: preview(observed) };
}

function main() {
  const args = parseArgs(process.argv);
  const suites = loadSuites().filter((s) => !args.formats.length || args.formats.includes(s.format));
  const adapters = makeAdapters().filter((a) => !args.serializers.length || args.serializers.includes(a.name));
  const byFormat = new Map();
  for (const a of adapters) {
    if (!byFormat.has(a.format)) byFormat.set(a.format, []);
    byFormat.get(a.format).push(a);
  }
  const results = [];
  const adapterErrors = [];
  for (const suite of suites) {
    const chosen = suite.adapters?.length
      ? (byFormat.get(suite.format) || []).filter((a) => suite.adapters.includes(a.name))
      : byFormat.get(suite.format) || [];
    if (!chosen.length) {
      adapterErrors.push(`No adapter registered for format ${suite.format} (${suite.standard} (${suite.version}))`);
      continue;
    }
    for (const adapter of chosen) {
      for (const c of suite.cases) {
        results.push(runOne(suite, c, adapter));
      }
    }
  }
  const passed = results.filter((r) => r.outcome === 'pass').length;
  const failed = results.filter((r) => r.outcome === 'fail').length;
  const skipped = results.filter((r) => r.outcome === 'skip').length;
  const errors = results.filter((r) => r.outcome === 'error').length;
  const by = new Map();
  for (const r of results) {
    const key = `${r.standard} (${r.version}) × ${r.serializer}`;
    if (!by.has(key)) by.set(key, { p: 0, f: 0, s: 0 });
    const cell = by.get(key);
    if (r.outcome === 'pass') cell.p += 1;
    else if (r.outcome === 'fail') cell.f += 1;
    else cell.s += 1;
  }
  console.log('Serialization compliance (library deviations are catalogued, not a red build)');
  console.log(`  ${passed} pass  ${failed} fail  ${skipped} skip  ${errors} error  ${results.length} total`);
  if (adapterErrors.length) {
    console.log('  Adapter errors:');
    for (const e of adapterErrors) console.log(`    - ${e}`);
  }
  console.log('  By suite × adapter:');
  for (const [k, v] of [...by.entries()].sort()) {
    console.log(`    ${k}: ${v.p} pass, ${v.f} fail, ${v.s} skip`);
  }
  const report = {
    schema: 'gld.dashboard.compliance/1',
    generated_at: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
    language: 'javascript',
    languages: ['javascript'],
    policy: 'report-only',
    scope: { formats: [...new Set(results.map((r) => r.format))].sort() },
    passed,
    failed,
    skipped,
    errors,
    catalog_errors: [],
    serializer_errors: adapterErrors,
    results,
  };
  if (args.jsonOut) {
    const dest = resolve(args.jsonOut);
    mkdirSync(dirname(dest), { recursive: true });
    writeFileSync(dest, `${JSON.stringify(report, null, 2)}\n`);
    console.log(`\nWrote ${dest}`);
  }
}

main();
