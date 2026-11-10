/**
 * Shared page helpers. HTML escaping and published JSON live in one place
 * so the views do not each grow a slightly different copy.
 */

export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Plain JSON or gzip JSON. The gzip magic bytes decide; a bad status throws. */
export async function decodeJsonBytes(bytes) {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const isGzip = view.length >= 2 && view[0] === 0x1f && view[1] === 0x8b;
  if (!isGzip) return JSON.parse(new TextDecoder().decode(view));
  if (typeof DecompressionStream === 'undefined') {
    throw new Error('gzip payload but DecompressionStream is unavailable');
  }
  // Read while writing. Awaiting write() before pulling readable deadlocks
  // once decompressed output fills the stream queue.
  const stream = new DecompressionStream('gzip');
  const textPromise = new Response(stream.readable).text();
  const writer = stream.writable.getWriter();
  await writer.write(view);
  await writer.close();
  return JSON.parse(await textPromise);
}

export async function fetchJsonMaybeGzip(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return decodeJsonBytes(new Uint8Array(await res.arrayBuffer()));
}
