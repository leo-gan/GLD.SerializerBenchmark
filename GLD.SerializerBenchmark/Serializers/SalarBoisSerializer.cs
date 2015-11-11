//
// See here https://github.com/salarcode/Bois
// PM> Install-Package Salar.Bois
// 

using System;
using System.IO;
using Salar.Bois;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class SalarBoisSerializer : SerDeser
    {
        private static readonly BoisSerializer _serializer = new BoisSerializer();

        #region ISerDeser Members

        public override string Name
        {
            get { return "Salar.Bois"; }
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(serializable, ms);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Deserialize<object>(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize<object>(inputStream);
        }

        #endregion
    }
}