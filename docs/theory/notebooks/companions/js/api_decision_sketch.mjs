#!/usr/bin/env node
/**
 * 101 engineering companion: decision sketch (human-readable? IDL? trust?).
 * Run: node api_decision_sketch.mjs
 */

function chooseFamily(humanReadable, needIdl, singleTrustedRuntime) {
  if (humanReadable) {
    return "Text/JSON family (+ validation layer for real contracts)";
  }
  if (needIdl) {
    return "Schema-driven (Protobuf/Avro-class)";
  }
  if (singleTrustedRuntime) {
    return "Language-native only inside a hard trust boundary";
  }
  return "Schemaless binary (MessagePack/CBOR-class) + validation at edges";
}

const scenarios = [
  ["Public REST body", true, false, false],
  ["Internal multi-lang RPC", false, true, false],
  ["Redis cache same service only", false, false, true],
  ["Internal queue, multi-service", false, false, false],
];

for (const [name, hum, idl, native] of scenarios) {
  console.log(name.padEnd(36), "→", chooseFamily(hum, idl, native));
}
