///
/// See here http://www.sharpserializer.com/en/index.html
/// >PM Install-Package SharpSerializer
/// 

using System;
using System.IO;
using Polenter.Serialization;

namespace GLD.SerializerBenchmark
{
    internal class SharpSerializer : ISerDeser
    {
        private static  Polenter.Serialization.SharpSerializer _serializer;

        public SharpSerializer() // TODO: Is it possible to assigh Type to serializer, so it could speed up?
        {
            var settings = new Polenter.Serialization.SharpSerializerBinarySettings
            {
                Mode = BinarySerializationMode.Burst
            };
            _serializer = new Polenter.Serialization.SharpSerializer(settings);
        }

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(person, ms);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            byte[] b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) _serializer.Deserialize(stream);
            }
        }

        #endregion
    }
}