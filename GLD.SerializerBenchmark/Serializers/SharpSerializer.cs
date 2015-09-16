///
/// See here http://www.sharpserializer.com/en/index.html
/// >PM Install-Package SharpSerializer
/// 

using System;
using System.IO;
using Polenter.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class SharpSerializer : SerDeser
    {
        private static Polenter.Serialization.SharpSerializer _serializer;

        public SharpSerializer() // TODO: Is it possible to assigh Type to serializer, so it could speed up?
        {
            var settings = new SharpSerializerBinarySettings
            {
                Mode = BinarySerializationMode.Burst
            };
            _serializer = new Polenter.Serialization.SharpSerializer(settings);
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "SharpSerializer"; }
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
                return _serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}