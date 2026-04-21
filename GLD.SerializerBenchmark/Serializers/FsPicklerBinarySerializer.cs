///
/// https://mbraceproject.github.io/FsPickler/
/// PM> Install-Package FsPickler
/// TODO: DateTime fields is still under work.

using System;
using System.IO;
using MBrace.FsPickler;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Wrapper stream that prevents the underlying stream from being closed.
    /// FsPickler closes streams after writing, which causes ObjectDisposedException.
    /// </summary>
    internal class NonClosingStreamWrapper : Stream
    {
        private readonly Stream _inner;
        public NonClosingStreamWrapper(Stream inner) { _inner = inner; }
        public override bool CanRead => _inner.CanRead;
        public override bool CanSeek => _inner.CanSeek;
        public override bool CanWrite => _inner.CanWrite;
        public override long Length => _inner.Length;
        public override long Position { get => _inner.Position; set => _inner.Position = value; }
        public override void Flush() => _inner.Flush();
        public override int Read(byte[] buffer, int offset, int count) => _inner.Read(buffer, offset, count);
        public override long Seek(long offset, SeekOrigin origin) => _inner.Seek(offset, origin);
        public override void SetLength(long value) => _inner.SetLength(value);
        public override void Write(byte[] buffer, int offset, int count) => _inner.Write(buffer, offset, count);
        protected override void Dispose(bool disposing) { /* Do not dispose inner stream */ }
    }

    internal class FsPicklerBinarySerializer : SerDeser
    {
        private readonly FsPicklerSerializer _serializer = FsPickler.CreateBinarySerializer();

        #region ISerDeser Members

        public override string Name
        {
            get { return "FsPickler"; }
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, serializable);
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                //stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Deserialize<object>(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            // FsPickler closes the stream, so we wrap it to prevent that
            using (var wrapper = new NonClosingStreamWrapper(outputStream))
            {
                _serializer.Serialize(wrapper, serializable);
            }
        }


        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize<object>(inputStream);
        }
        #endregion
    }
}