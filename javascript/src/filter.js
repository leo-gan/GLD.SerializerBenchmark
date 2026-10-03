/**
 * Serializer name filter for the v2 runner.
 * Empty selects every registered name.
 * A filter with no comma is a case-insensitive substring.
 * A comma-separated filter is case-insensitive exact names only,
 * so "json" does not select every JSON library and "parquet"
 * does not select "parquet-uncompressed".
 */
export function serializerSelected(name, filter) {
  const raw = String(filter ?? '').trim();
  if (!raw) return true;
  const n = String(name).toLowerCase();
  if (!raw.includes(',')) return n.includes(raw.toLowerCase());
  const tokens = raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  return tokens.includes(n);
}
