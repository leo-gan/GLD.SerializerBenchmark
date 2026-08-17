import zlib from 'node:zlib';

/** One-shot gzip(6) / zstd(3) of already-written bytes. Not timed. */
export function compressSizes(buf) {
  if (buf == null) return [0, 0];
  const raw = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  if (raw.length === 0) return [0, 0];
  let gz = 0;
  let zs = 0;
  try {
    gz = zlib.gzipSync(raw, { level: 6 }).length;
  } catch {
    gz = 0;
  }
  if (typeof zlib.zstdCompressSync === 'function') {
    try {
      const params = {};
      if (zlib.constants && zlib.constants.ZSTD_c_compressionLevel != null) {
        params[zlib.constants.ZSTD_c_compressionLevel] = 3;
      }
      zs = zlib.zstdCompressSync(raw, { params }).length;
    } catch {
      zs = 0;
    }
  }
  return [gz, zs];
}
