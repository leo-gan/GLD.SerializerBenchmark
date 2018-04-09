///
/// https://mbraceproject.github.io/FsPickler/
/// PM> Install-Package FsPickler
/// TODO: DateTime fields is still under work.

using System;
using System.IO;
using MBrace.FsPickler;

namespace GLD.SerializerBenchmark.Serializers
{
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
            _serializer.Serialize(outputStream, serializable);
        }


        public override object Deserialize(Stream inputStream)
        {
            //inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize<object>(inputStream);
        }
        #endregion
    }
}