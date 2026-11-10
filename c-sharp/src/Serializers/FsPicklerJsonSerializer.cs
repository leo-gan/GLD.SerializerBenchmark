///
/// https://mbraceproject.github.io/FsPickler/
/// PM> Install-Package FsPickler.Json

using System;
using System.IO;
using System.Text;
using MBrace.FsPickler.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class FsPicklerJsonSerializer : SerDeser
    {
        private readonly JsonSerializer _serializer = FsPickler.CreateJsonSerializer();

        #region ISerDeser Members

        public override string Name
        {
            get { return "FsPicklerJson"; }
        }

        public override byte[] SerializeBytes(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, serializable);
                return ms.ToArray();
            }
        }

        public override object DeserializeBytes(byte[] serialized)
        {
            using (var stream = new MemoryStream(serialized))
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