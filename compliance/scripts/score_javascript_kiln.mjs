// Score Kiln wire v2 with the benchmark's installed gld-kiln 0.2.0.
// Dashboard outcome matches Mojo: reject on any KilnError, accept on a matching value.
import { cpSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Node refuses to strip TypeScript inside node_modules, so score a copy.
const root = dirname(fileURLToPath(import.meta.url));
const installed = join(root, "..", "..", "javascript", "node_modules", "gld-kiln");
const copy = "/tmp/gld-kiln-js-score";
rmSync(copy, { recursive: true, force: true });
cpSync(installed, copy, { recursive: true });
const {
  KilnError,
  VERSION,
  decode,
  decodeFramed,
  encode,
  encodeFramed,
  schemaFromCase,
  typeHash,
} = await import(pathToFileURL(join(copy, "src", "index.ts")).href);

const catalog = join(root, "..", "data", "kiln", "v2.json");
const text = readFileSync(catalog, "utf8").replace(/("hash"\s*:\s*)(\d+)/g, '$1"$2"');
const doc = JSON.parse(text);

function isDirectory(value) {
  return !!value && typeof value === "object" && "tensors" in value && "block_length" in value;
}

function project(value) {
  if (isDirectory(value)) {
    return {
      version: value.version,
      flags: value.flags,
      tensors: value.tensors.map((item) => ({
        name: item.name,
        dtype: item.dtype,
        shape: item.shape,
        quant_scheme: item.quant_scheme,
        data_hex: Buffer.from(item.data).toString("hex"),
      })),
      block_length: value.block_length,
    };
  }
  if (Array.isArray(value)) return value.map(project);
  if (value && typeof value === "object" && !(value instanceof Uint8Array)) {
    const out = {};
    for (const [key, item] of Object.entries(value)) out[key] = project(item);
    return out;
  }
  return value;
}

function same(got, want) {
  if (typeof want === "number" && typeof got === "number") {
    if (Number.isNaN(want) && Number.isNaN(got)) return true;
    return Object.is(got, want);
  }
  if (typeof want === "bigint" && typeof got === "bigint") return got === want;
  if (Array.isArray(want) && Array.isArray(got)) {
    return want.length === got.length && want.every((item, i) => same(got[i], item));
  }
  if (want && typeof want === "object" && got && typeof got === "object" && !Array.isArray(want)) {
    return Object.keys(want).every((key) => key in got && same(got[key], want[key]));
  }
  return got === want;
}

function score(entry) {
  const raw = Buffer.from(String(entry.input), "hex");
  const schema = schemaFromCase(entry.schema);
  const framed = entry.schema === "frame";
  let stricter = "";
  try {
    const value = framed ? decodeFramed(schema, raw) : decode(schema, raw);
    if (entry.expect === "reject") {
      return { id: entry.id, outcome: "fail", observed: "accept", detail: "decoded a buffer the catalog rejects", stricter: "accepted" };
    }
    if ("decoded" in entry) {
      const decoded = entry.decoded;
      let want = decoded;
      if (framed) {
        const wantHash = BigInt(decoded.hash);
        if (typeHash(schema) !== wantHash) {
          return {
            id: entry.id,
            outcome: "fail",
            observed: "accept",
            detail: `type hash ${typeHash(schema)} != ${wantHash}`,
            stricter: "hash",
          };
        }
        want = { id: decoded.id, batch: decoded.batch };
      }
      if (!same(project(value), want)) {
        return { id: entry.id, outcome: "fail", observed: "accept", detail: "decoded value does not match", stricter: "value" };
      }
    }
    try {
      const again = Buffer.from(framed ? encodeFramed(schema, value) : encode(schema, value));
      if (!again.equals(raw)) stricter = "re-encode mismatch";
    } catch (err) {
      stricter = err instanceof KilnError ? `re-encode ${err.code}` : `re-encode ${err}`;
    }
    return { id: entry.id, outcome: "pass", observed: "ok", detail: stricter, stricter };
  } catch (err) {
    if (entry.expect !== "reject") {
      const code = err instanceof KilnError ? err.code : "error";
      return { id: entry.id, outcome: "fail", observed: "reject", detail: `${code}: ${err}`, stricter: "reject" };
    }
    if (!(err instanceof KilnError)) {
      return { id: entry.id, outcome: "fail", observed: "error", detail: String(err), stricter: "not KilnError" };
    }
    if (err.code !== entry.error) stricter = `error ${err.code}, catalog ${entry.error}`;
    return { id: entry.id, outcome: "pass", observed: "reject", detail: stricter, stricter };
  }
}

const cases = doc.cases.map(score);
const failed = cases.filter((row) => row.outcome !== "pass");
const out = {
  language: "javascript",
  serializer: "gld-kiln",
  serializer_version: VERSION,
  pin: `javascript/node_modules/gld-kiln ${VERSION}`,
  passed: cases.length - failed.length,
  failed: failed.length,
  stricter_failed: cases.filter((row) => row.stricter).length,
  cases,
};
writeFileSync("/tmp/kiln-scores/javascript.json", JSON.stringify(out));
console.log(`version=${VERSION} pass=${out.passed} fail=${out.failed} stricter_fail=${out.stricter_failed}`);
for (const row of failed) console.log(row.id, row.outcome, row.observed, row.detail);
if (failed.length) process.exit(1);
