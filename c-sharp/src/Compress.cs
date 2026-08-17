using System.IO;
using System.IO.Compression;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    /// One-shot gzip(6) of already-written bytes. Not on the timed path.
    /// zstd is 0: no encoder ships with net8.0.
    /// </summary>
    internal static class Compress
    {
        public static void Sizes(byte[] raw, out int gzip, out int zstd)
        {
            gzip = 0;
            zstd = 0;
            if (raw == null || raw.Length == 0) return;
            using var ms = new MemoryStream();
            // CompressionLevel.Optimal is zlib's default (~level 6).
            using (var gz = new GZipStream(ms, CompressionLevel.Optimal, leaveOpen: true))
                gz.Write(raw, 0, raw.Length);
            gzip = (int)ms.Length;
        }
    }
}
