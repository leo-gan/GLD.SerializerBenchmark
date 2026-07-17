#!/usr/bin/env node
/**
 * 101/201 companion: same logical DTO, JSON vs a tiny tagged-binary sketch.
 * Run: node json_vs_binary_size.mjs
 * No npm deps.
 */

const DTO = {
  request_id: "req-7f3a",
  user_id: 42,
  items: [
    { sku: "A-1", qty: 2 },
    { sku: "B-9", qty: 1 },
  ],
  metadata: { source: "web", attempt: 1 },
};

function encodeVarint(u) {
  const out = [];
  while (u > 0x7f) {
    out.push((u & 0x7f) | 0x80);
    u >>>= 7;
  }
  out.push(u & 0x7f);
  return Buffer.from(out);
}

function encodeKey(fn, wt) {
  return encodeVarint((fn << 3) | wt);
}

/** Teaching sketch only — not Protobuf production encoding of nested messages. */
function encodeDtoSketch(d) {
  const parts = [];
  const rid = Buffer.from(d.request_id, "utf8");
  parts.push(encodeKey(1, 2), encodeVarint(rid.length), rid);
  parts.push(encodeKey(2, 0), encodeVarint(d.user_id));
  const items = Buffer.from(JSON.stringify(d.items), "utf8");
  parts.push(encodeKey(3, 2), encodeVarint(items.length), items);
  const meta = Buffer.from(JSON.stringify(d.metadata), "utf8");
  parts.push(encodeKey(4, 2), encodeVarint(meta.length), meta);
  return Buffer.concat(parts);
}

const json = Buffer.from(JSON.stringify(DTO), "utf8");
const sketch = encodeDtoSketch(DTO);

console.log("encoding".padEnd(22), "nbytes".padStart(6));
console.log("JSON".padEnd(22), String(json.length).padStart(6));
console.log("tagged-binary sketch".padEnd(22), String(sketch.length).padStart(6));
console.log("JSON preview:", json.toString().slice(0, 80) + "…");
console.log(
  "Decision: public REST → JSON + validation; internal multi-lang → IDL/binary with a real schema."
);
