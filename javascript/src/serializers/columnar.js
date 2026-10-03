/**
 * Columnar bytes codecs: Apache Arrow IPC stream, and hyparquet Parquet.
 * Schema objects are selected in prepare. Row-to-column conversion is inside
 * serialize. table_project deserialize returns f_float_0 only (length N, including N=1).
 * No Arrow file format, no parquet-wasm, no ORC, no SBE.
 */
import {
  Field,
  Float64,
  Int32,
  Int64,
  List,
  RecordBatchStreamReader,
  Schema,
  Struct,
  Table,
  Utf8,
  makeBuilder,
  tableFromIPC,
  tableToIPC,
  vectorFromArray,
} from 'apache-arrow';
import { parquetReadObjects } from 'hyparquet';
import { parquetWriteBuffer } from 'hyparquet-writer';
import { columnarSupports, pkgVersion } from './common.js';

const floatFields = [];
for (let i = 0; i < 16; i++) floatFields.push(new Field(`f_float_${i}`, new Float64(), false));
const intFields = [];
for (let i = 0; i < 4; i++) intFields.push(new Field(`f_int_${i}`, new Int64(), false));
const TABLE_SCHEMA = new Schema([
  ...floatFields,
  ...intFields,
  new Field('f_str_0', new Utf8(), false),
  new Field('f_str_1', new Utf8(), false),
]);

const nestedItemType = new Struct([
  new Field('sku', new Utf8(), false),
  new Field('qty', new Int32(), false),
  new Field('price_minor', new Int64(), false),
]);
const nestedMetaType = new Struct([
  new Field('region', new Utf8(), false),
  new Field('version', new Int32(), false),
]);
const NESTED_SCHEMA = new Schema([
  new Field('id', new Utf8(), false),
  new Field('status', new Int32(), false),
  new Field('meta', nestedMetaType, false),
  new Field('items', new List(new Field('item', nestedItemType, false)), false),
]);

const signalLegType = new Struct([
  new Field('leg_id', new Int64(), false),
  new Field('leg_qty', new Int32(), false),
  new Field('leg_pad', new Int32(), false),
]);
const SIGNAL_SCHEMA = new Schema([
  new Field('seq', new Int64(), false),
  new Field('ts', new Int64(), false),
  new Field('price_mantissa', new Int64(), false),
  new Field('qty', new Int32(), false),
  new Field('flags', new Int32(), false),
  new Field('symbol', new Utf8(), false),
  new Field('venue', new Utf8(), false),
  new Field('legs', new List(new Field('item', signalLegType, false)), false),
]);

const ARROW_SCHEMAS = {
  table: TABLE_SCHEMA,
  table_project: TABLE_SCHEMA,
  nested_table: NESTED_SCHEMA,
  signal: SIGNAL_SCHEMA,
};

function pqUtf8(name) {
  return { name, type: 'BYTE_ARRAY', converted_type: 'UTF8', repetition_type: 'REQUIRED' };
}
function pqI32(name) {
  return { name, type: 'INT32', repetition_type: 'REQUIRED' };
}
function pqI64(name) {
  return { name, type: 'INT64', repetition_type: 'REQUIRED' };
}
function pqF64(name) {
  return { name, type: 'DOUBLE', repetition_type: 'REQUIRED' };
}

const TABLE_PQ = [
  { name: 'root', num_children: 22 },
  ...Array.from({ length: 16 }, (_, i) => pqF64(`f_float_${i}`)),
  ...Array.from({ length: 4 }, (_, i) => pqI64(`f_int_${i}`)),
  pqUtf8('f_str_0'),
  pqUtf8('f_str_1'),
];

const NESTED_PQ = [
  { name: 'root', num_children: 4 },
  pqUtf8('id'),
  pqI32('status'),
  { name: 'meta', repetition_type: 'REQUIRED', num_children: 2 },
  pqUtf8('region'),
  pqI32('version'),
  { name: 'items', converted_type: 'LIST', repetition_type: 'REQUIRED', num_children: 1 },
  { name: 'list', repetition_type: 'REPEATED', num_children: 1 },
  { name: 'element', repetition_type: 'REQUIRED', num_children: 3 },
  pqUtf8('sku'),
  pqI32('qty'),
  pqI64('price_minor'),
];

const SIGNAL_PQ = [
  { name: 'root', num_children: 8 },
  pqI64('seq'),
  pqI64('ts'),
  pqI64('price_mantissa'),
  pqI32('qty'),
  pqI32('flags'),
  pqUtf8('symbol'),
  pqUtf8('venue'),
  { name: 'legs', converted_type: 'LIST', repetition_type: 'REQUIRED', num_children: 1 },
  { name: 'list', repetition_type: 'REPEATED', num_children: 1 },
  { name: 'element', repetition_type: 'REQUIRED', num_children: 3 },
  pqI64('leg_id'),
  pqI32('leg_qty'),
  pqI32('leg_pad'),
];

const PARQUET_SCHEMAS = {
  table: TABLE_PQ,
  table_project: TABLE_PQ,
  nested_table: NESTED_PQ,
  signal: SIGNAL_PQ,
};

function rowsOf(value, batch) {
  return batch ? value : [value];
}

function buildFlatTable(schema, rows) {
  const cols = {};
  for (const field of schema.fields) {
    const name = field.name;
    // DataType.typeId is the coarse kind (Float/Int). Float64 and Int64 are subclasses.
    if (field.type instanceof Float64) {
      cols[name] = vectorFromArray(
        Float64Array.from(rows, (row) => row[name]),
        field.type,
      );
    } else if (field.type instanceof Int64) {
      const arr = new BigInt64Array(rows.length);
      for (let i = 0; i < rows.length; i++) arr[i] = BigInt(rows[i][name]);
      cols[name] = vectorFromArray(arr, field.type);
    } else if (field.type instanceof Utf8) {
      const strings = new Array(rows.length);
      for (let i = 0; i < rows.length; i++) strings[i] = rows[i][name];
      cols[name] = vectorFromArray(strings, field.type);
    } else {
      throw new Error(`arrow-ipc: unsupported flat field ${name}`);
    }
  }
  return new Table(schema, cols);
}

function nestedArrowRow(row) {
  return {
    id: row.id,
    status: row.status | 0,
    meta: { region: row.meta.region, version: row.meta.version | 0 },
    items: (row.items || []).map((it) => ({
      sku: it.sku,
      qty: it.qty | 0,
      price_minor: BigInt(it.price_minor),
    })),
  };
}

function signalArrowRow(row) {
  return {
    seq: BigInt(row.seq),
    ts: BigInt(row.ts),
    price_mantissa: BigInt(row.price_mantissa),
    qty: row.qty | 0,
    flags: row.flags | 0,
    symbol: row.symbol,
    venue: row.venue,
    legs: (row.legs || []).map((leg) => ({
      leg_id: BigInt(leg.leg_id),
      leg_qty: leg.leg_qty | 0,
      leg_pad: leg.leg_pad | 0,
    })),
  };
}

function buildStructTable(schema, rows) {
  const builder = makeBuilder({
    type: new Struct(schema.fields),
    nullValues: [undefined],
  });
  for (const row of rows) builder.append(row);
  const vec = builder.finish().toVector();
  const cols = {};
  for (const field of schema.fields) cols[field.name] = vec.getChild(field.name);
  return new Table(cols);
}

function ipcBytes(table) {
  // 'stream' is the IPC stream. The Arrow file format is a different container.
  const ipc = tableToIPC(table, 'stream');
  return Buffer.from(ipc.buffer, ipc.byteOffset, ipc.byteLength);
}

/**
 * Read an IPC stream. columns selects fields before record batches are loaded
 * (schema.select + reset). The JS reader has no included_fields option.
 */
export function readArrowIpc(bytes, columns) {
  const u8 = bytes instanceof Uint8Array ? bytes : Uint8Array.from(bytes);
  if (!columns || columns.length === 0) return tableFromIPC(u8);
  const reader = RecordBatchStreamReader.from(u8);
  reader.open();
  const projected = reader.schema.select(columns);
  reader.reset(projected);
  const batches = [];
  for (;;) {
    const step = reader.next();
    if (step && typeof step.then === 'function') {
      throw new Error('arrow-ipc: stream reader next() returned a promise');
    }
    if (!step || step.done) break;
    if (step.value && step.value.numRows > 0) batches.push(step.value);
  }
  if (batches.length === 0) throw new Error('arrow-ipc: empty projected stream');
  return new Table(batches);
}

function fromArrow(value) {
  if (typeof value === 'bigint') return Number(value);
  if (value == null || typeof value !== 'object') return value;
  if (
    typeof value.toJSON === 'function' &&
    Object.prototype.toString.call(value) === '[object Row]'
  ) {
    return fromArrow(value.toJSON());
  }
  if (typeof value.get === 'function' && typeof value.length === 'number' && value.type) {
    const n = value.length;
    const out = new Array(n);
    for (let i = 0; i < n; i++) out[i] = fromArrow(value.get(i));
    return out;
  }
  if (Array.isArray(value)) {
    const out = new Array(value.length);
    for (let i = 0; i < value.length; i++) out[i] = fromArrow(value[i]);
    return out;
  }
  const out = {};
  for (const key of Object.keys(value)) out[key] = fromArrow(value[key]);
  return out;
}

function materializeArrow(typeId, batch, table) {
  if (typeId === 'table_project') {
    const col = table.getChild('f_float_0');
    if (!col) throw new Error('arrow-ipc: projected stream has no f_float_0');
    const values = col.toArray();
    const out = new Array(values.length);
    for (let i = 0; i < values.length; i++) out[i] = Number(values[i]);
    return out;
  }
  const raw = table.toArray();
  const rows = new Array(raw.length);
  for (let i = 0; i < raw.length; i++) rows[i] = fromArrow(raw[i]);
  return batch ? rows : rows[0];
}

function makeArrow() {
  let typeId = 'table';
  let batch = false;
  let schema = TABLE_SCHEMA;
  return {
    name: 'arrow-ipc',
    version: pkgVersion('apache-arrow'),
    category: 'columnar',
    supports: columnarSupports,
    prepare(dataName, value) {
      typeId = dataName;
      batch = Array.isArray(value);
      schema = ARROW_SCHEMAS[dataName];
      if (!schema) throw new Error(`arrow-ipc: no schema for ${dataName}`);
    },
    serialize(value) {
      const rows = rowsOf(value, batch);
      let table;
      if (typeId === 'nested_table') table = buildStructTable(schema, rows.map(nestedArrowRow));
      else if (typeId === 'signal') table = buildStructTable(schema, rows.map(signalArrowRow));
      else table = buildFlatTable(schema, rows);
      return ipcBytes(table);
    },
    deserialize(buf) {
      const columns = typeId === 'table_project' ? ['f_float_0'] : null;
      return materializeArrow(typeId, batch, readArrowIpc(buf, columns));
    },
  };
}

function parquetColumns(typeId, rows) {
  if (typeId === 'nested_table') {
    return [
      { name: 'id', data: rows.map((r) => r.id) },
      { name: 'status', data: rows.map((r) => r.status) },
      { name: 'meta', data: rows.map((r) => r.meta) },
      {
        name: 'items',
        data: rows.map((r) =>
          (r.items || []).map((it) => ({
            sku: it.sku,
            qty: it.qty,
            price_minor: BigInt(it.price_minor),
          })),
        ),
      },
    ];
  }
  if (typeId === 'signal') {
    return [
      { name: 'seq', data: rows.map((r) => BigInt(r.seq)) },
      { name: 'ts', data: rows.map((r) => BigInt(r.ts)) },
      { name: 'price_mantissa', data: rows.map((r) => BigInt(r.price_mantissa)) },
      { name: 'qty', data: rows.map((r) => r.qty) },
      { name: 'flags', data: rows.map((r) => r.flags) },
      { name: 'symbol', data: rows.map((r) => r.symbol) },
      { name: 'venue', data: rows.map((r) => r.venue) },
      {
        name: 'legs',
        data: rows.map((r) =>
          (r.legs || []).map((leg) => ({
            leg_id: BigInt(leg.leg_id),
            leg_qty: leg.leg_qty,
            leg_pad: leg.leg_pad | 0,
          })),
        ),
      },
    ];
  }
  const cols = [];
  for (let i = 0; i < 16; i++) {
    const name = `f_float_${i}`;
    cols.push({ name, data: rows.map((r) => r[name]) });
  }
  for (let i = 0; i < 4; i++) {
    const name = `f_int_${i}`;
    cols.push({ name, data: rows.map((r) => BigInt(r[name])) });
  }
  cols.push({ name: 'f_str_0', data: rows.map((r) => r.f_str_0) });
  cols.push({ name: 'f_str_1', data: rows.map((r) => r.f_str_1) });
  return cols;
}

function toArrayBuffer(buf) {
  if (buf instanceof ArrayBuffer) return buf;
  const u8 = buf instanceof Uint8Array ? buf : Buffer.from(buf);
  // A Node Buffer is often a view into a pool. DataView requires a real ArrayBuffer.
  if (u8.byteOffset === 0 && u8.byteLength === u8.buffer.byteLength) return u8.buffer;
  return u8.buffer.slice(u8.byteOffset, u8.byteOffset + u8.byteLength);
}

function normalize(value) {
  if (typeof value === 'bigint') return Number(value);
  if (Array.isArray(value)) {
    const out = new Array(value.length);
    for (let i = 0; i < value.length; i++) out[i] = normalize(value[i]);
    return out;
  }
  if (value && typeof value === 'object') {
    const out = {};
    for (const key of Object.keys(value)) out[key] = normalize(value[key]);
    return out;
  }
  return value;
}

function finishParquet(typeId, batch, rows) {
  const plain = new Array(rows.length);
  for (let i = 0; i < rows.length; i++) plain[i] = normalize(rows[i]);
  if (typeId === 'table_project') {
    const out = new Array(plain.length);
    for (let i = 0; i < plain.length; i++) out[i] = plain[i].f_float_0;
    return out;
  }
  return batch ? plain : plain[0];
}

function makeParquet(name, codec) {
  let typeId = 'table';
  let batch = false;
  let schema = TABLE_PQ;
  return {
    name,
    version: pkgVersion('hyparquet-writer'),
    category: 'columnar',
    supports: columnarSupports,
    prepare(dataName, value) {
      typeId = dataName;
      batch = Array.isArray(value);
      schema = PARQUET_SCHEMAS[dataName];
      if (!schema) throw new Error(`${name}: no schema for ${dataName}`);
    },
    serialize(value) {
      const rows = rowsOf(value, batch);
      const opts = { schema, columnData: parquetColumns(typeId, rows) };
      // Omitted codec is the library default (SNAPPY). UNCOMPRESSED is a real switch.
      if (codec) opts.codec = codec;
      return Buffer.from(parquetWriteBuffer(opts));
    },
    async deserialize(buf) {
      const options = { file: toArrayBuffer(buf) };
      if (typeId === 'table_project') options.columns = ['f_float_0'];
      const rows = await parquetReadObjects(options);
      return finishParquet(typeId, batch, rows);
    },
  };
}

export function columnarSerializers() {
  return [
    makeArrow(),
    makeParquet('parquet', null),
    makeParquet('parquet-uncompressed', 'UNCOMPRESSED'),
  ];
}
