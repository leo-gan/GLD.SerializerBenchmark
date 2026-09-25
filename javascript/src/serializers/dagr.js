/**
 * Dagr ("Data Graph") — schemas/v2/dagr/schema.py → `dagr build` → src/generated/dagr/*.ts,
 * compiled to src/generated/dagr_bundle.js by scripts/generate-dagr.sh (esbuild: the
 * generated TS uses extension-less imports and CI runs Node 20, so no native type stripping).
 *
 * The schema emits every suite type in four node layouts (spec/16-choosing-a-node-layout.md),
 * one row each: `dagr` (packed), `dagr-regular`, `dagr-frozen`, `dagr-frozen-packed`.
 *
 * packed / frozen+packed: serialize uses the generated **direct
 * builder** (`writeInto`: plain value objects → bytes, no arena) into one `Builder` reused
 * across calls (`reset()`). The value objects are the codec's native model, so — like the
 * protobuf libraries' messages — they are built in `prepare()` (untimed), every field set. Deserialize uses
 * the generated **lazy reader** (`<Type>Accessor.lazyRoot`) and materializes the domain
 * value inside the timed path (i64 fields are `bigint` on the Dagr side → Number).
 *
 * regular / frozen: the generator emits no direct builder for a non-packed root, so the
 * native model is the generated **arena** (`<Graph>_arena`, one arena per record, built in
 * `prepare()`); the timed path is only the arena serializer `<Graph>_serde.toBytes` (it
 * allocates its own `Builder` per call — the generated API offers no reuse). Deserialize is
 * the same lazy-reader → domain code for all four layouts (the accessor API is identical).
 *
 * Batch N>1: [u32 count][u32 len][record]… (same framing as the Rust harness).
 * Version: generator version from the committed receipt schemas/v2/dagr/dagr.lock.json.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as G from '../generated/dagr_bundle.js';

const { Builder } = G;

const __dirname = dirname(fileURLToPath(import.meta.url));

function dagrVersion() {
  try {
    const lock = JSON.parse(
      readFileSync(join(__dirname, '../../../schemas/v2/dagr/dagr.lock.json'), 'utf8'),
    );
    const m = /(\d+\.\d+\.\d+\S*)/.exec(String(lock.provenance?.tool_version ?? ''));
    return m ? m[1] : '';
  } catch {
    return '';
  }
}

const big = (v) => BigInt(v);
const num = (v) => (v === null ? 0 : Number(v));
const str = (v) => (v === null ? '' : v);

/* ---------- encode: direct-builder values (prepared, untimed) → bytes (timed) ---------- */

// One builder for the whole run: each encode resets it and stores the record at its far
// end; `recordBytes()` is a view of that record, valid until the next encode.
const B = new Builder(2 * 1024 * 1024, 4096);

// Domain → direct-builder value objects. These are the codec's native model (the
// counterpart of the protobuf libraries' message objects), so — like them — they are
// built in `prepare()`, outside the timer.
const converters = {
  message: (m) => ({
    f_bool: m.f_bool,
    f_int32: m.f_int32,
    f_int64: big(m.f_int64),
    f_float64: m.f_float64,
    f_string: m.f_string,
    f_bool_2: m.f_bool_2,
    f_int32_2: m.f_int32_2,
    f_string_2: m.f_string_2,
  }),
  document: (d) => ({
    id: d.id,
    status: d.status,
    meta: { region: d.meta.region, version: d.meta.version },
    items: d.items.map((it) => ({ sku: it.sku, qty: it.qty, price_minor: big(it.price_minor) })),
  }),
  telemetry: (t) => ({ source: t.source, ts: big(t.ts), tags: t.tags, values: t.values }),
  strings: (s) => ({ items: s.items }),
  event: (e) => ({
    event_id: e.event_id,
    event_type: e.event_type,
    occurred_at: big(e.occurred_at),
    producer: e.producer,
    attrs: e.attrs.map((a) => ({ key: a.key, value: a.value })),
  }),
};

const TYPES = {
  message: 'Message',
  document: 'Document',
  telemetry: 'Telemetry',
  strings: 'Strings',
  event: 'Event',
};

// Timed: the generated direct builder's writeInto (into the shared `B`).
const directWriters = (flavour) =>
  Object.fromEntries(
    Object.entries(TYPES).map(([id, T]) => {
      const Direct = G[`${T}${flavour}Direct`];
      return [id, (v) => Direct.writeInto(v, B)];
    }),
  );

// Domain → arena (regular / frozen: their native model; built in prepare(), untimed).
// One arena per record; the value is the root handle.
function arenaBuilders(flavour) {
  const A = (T) => G[`${T}${flavour}Arena`].Arena;
  return {
    message: (m) =>
      new (A('Message'))().newMessage(
        m.f_bool, m.f_int32, big(m.f_int64), m.f_float64,
        m.f_string, m.f_bool_2, m.f_int32_2, m.f_string_2,
      ),
    document: (d) => {
      const a = new (A('Document'))();
      const meta = a.newDocumentMeta(d.meta.region, d.meta.version);
      const items = d.items.map((it) => a.newDocumentItem(it.sku, it.qty, big(it.price_minor)));
      return a.newDocument(d.id, d.status, meta, items);
    },
    telemetry: (t) => new (A('Telemetry'))().newTelemetry(t.source, big(t.ts), t.tags, t.values),
    strings: (s) => new (A('Strings'))().newStrings(s.items),
    event: (e) => {
      const a = new (A('Event'))();
      const attrs = e.attrs.map((x) => a.newEventAttr(x.key, x.value));
      return a.newEvent(e.event_id, e.event_type, big(e.occurred_at), e.producer, attrs);
    },
  };
}

// Timed: the generated arena serializer (returns a fresh record).
const serdeWriters = (flavour) =>
  Object.fromEntries(
    Object.entries(TYPES).map(([id, T]) => {
      const Serde = G[`${T}${flavour}Serde`];
      return [id, (root) => Serde.toBytes(root)];
    }),
  );

/* ---------- decode: lazy reader → domain ---------- */

const makeDecoders = (flavour) => {
  const L = (T) => G[`${T}${flavour}Lazy`];
  return {
    message: (u8) => {
      const m = L('Message').MessageAccessor.lazyRoot(u8);
      return {
        f_bool: m.f_bool ?? false,
        f_int32: num(m.f_int32),
        f_int64: num(m.f_int64),
        f_float64: num(m.f_float64),
        f_string: str(m.f_string),
        f_bool_2: m.f_bool_2 ?? false,
        f_int32_2: num(m.f_int32_2),
        f_string_2: str(m.f_string_2),
      };
    },
    document: (u8) => {
      const d = L('Document').DocumentAccessor.lazyRoot(u8);
      const meta = d.meta;
      const src = d.items ?? [];
      const items = new Array(src.length);
      for (let i = 0; i < src.length; i++) {
        const it = src[i];
        items[i] = { sku: str(it.sku), qty: num(it.qty), price_minor: num(it.price_minor) };
      }
      return {
        id: str(d.id),
        status: num(d.status),
        meta: { region: str(meta?.region ?? null), version: num(meta?.version ?? null) },
        items,
      };
    },
    telemetry: (u8) => {
      const t = L('Telemetry').TelemetryAccessor.lazyRoot(u8);
      return { source: str(t.source), ts: num(t.ts), tags: t.tags ?? [], values: t.values ?? [] };
    },
    strings: (u8) => ({ items: L('Strings').StringsAccessor.lazyRoot(u8).items ?? [] }),
    event: (u8) => {
      const e = L('Event').EventAccessor.lazyRoot(u8);
      const src = e.attrs ?? [];
      const attrs = new Array(src.length);
      for (let i = 0; i < src.length; i++) {
        attrs[i] = { key: str(src[i].key), value: str(src[i].value) };
      }
      return {
        event_id: str(e.event_id),
        event_type: str(e.event_type),
        occurred_at: num(e.occurred_at),
        producer: str(e.producer),
        attrs,
      };
    },
  };
};

/* ---------- batch framing ---------- */

let scratch = new Uint8Array(1 << 16);

// Direct builder: stores into `B`; the record is a view valid until the next encode.
function encodeDirect(encode, value) {
  B.reset();
  encode(value);
  return B.recordBytes();
}

function encodeBatch(record, encode, values) {
  const n = values.length;
  let o = 4;
  for (let i = 0; i < n; i++) {
    const rec = record(encode, values[i]);
    const need = o + 4 + rec.length;
    if (need > scratch.length) {
      let cap = scratch.length * 2;
      while (cap < need) cap *= 2;
      const grown = new Uint8Array(cap);
      grown.set(scratch.subarray(0, o));
      scratch = grown;
    }
    scratch[o] = rec.length & 0xff;
    scratch[o + 1] = (rec.length >>> 8) & 0xff;
    scratch[o + 2] = (rec.length >>> 16) & 0xff;
    scratch[o + 3] = (rec.length >>> 24) & 0xff;
    scratch.set(rec, o + 4);
    o = need;
  }
  scratch[0] = n & 0xff;
  scratch[1] = (n >>> 8) & 0xff;
  scratch[2] = (n >>> 16) & 0xff;
  scratch[3] = (n >>> 24) & 0xff;
  return scratch.slice(0, o);
}

function decodeBatch(decode, u8) {
  const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
  const n = dv.getUint32(0, true);
  const out = new Array(n);
  let o = 4;
  for (let i = 0; i < n; i++) {
    const len = dv.getUint32(o, true);
    o += 4;
    out[i] = decode(u8.subarray(o, o + len));
    o += len;
  }
  return out;
}

// Arena serializer: already returns a fresh, owned record.
const encodeSerde = (encode, root) => encode(root);

/**
 * One row per node layout. `flavour` is the graph-name infix of the bundle exports
 * ('' = packed, 'Regular', 'Frozen', 'FrozenPacked'); `direct` picks the direct builder
 * (packed-rooted graphs) over the arena + arena serializer.
 */
function makeDagrSer(name, flavour, direct) {
  const convs = direct ? converters : arenaBuilders(flavour);
  const writers = direct ? directWriters(flavour) : serdeWriters(flavour);
  const record = direct ? encodeDirect : encodeSerde;
  const decoders = makeDecoders(flavour);
  let encodeOne = null;
  let decodeOne = null;
  let isBatch = false;
  let prepared = null;   // native-model value(s) for the cell, built in prepare()
  return {
    name,
    version: dagrVersion(),
    category: 'schema',
    supports: (dataName) => Object.prototype.hasOwnProperty.call(writers, dataName),
    prepare(dataName, value) {
      const conv = convs[dataName];
      encodeOne = writers[dataName];
      decodeOne = decoders[dataName];
      if (!encodeOne) throw new Error(`${name}: no graph for ${dataName}`);
      isBatch = Array.isArray(value);
      prepared = isBatch ? value.map(conv) : conv(value);
    },
    serialize() {
      if (isBatch) return encodeBatch(record, encodeOne, prepared);
      // Direct: copy the record out of the reused builder; serde already owns its bytes.
      return direct ? encodeDirect(encodeOne, prepared).slice() : encodeOne(prepared);
    },
    deserialize(buf) {
      return isBatch ? decodeBatch(decodeOne, buf) : decodeOne(buf);
    },
  };
}

export const dagrSer = makeDagrSer('dagr', '', true);
export const dagrRegularSer = makeDagrSer('dagr-regular', 'Regular', false);
export const dagrFrozenSer = makeDagrSer('dagr-frozen', 'Frozen', false);
export const dagrFrozenPackedSer = makeDagrSer('dagr-frozen-packed', 'FrozenPacked', true);

export function dagrSerializers() {
  return [dagrSer, dagrRegularSer, dagrFrozenSer, dagrFrozenPackedSer];
}
