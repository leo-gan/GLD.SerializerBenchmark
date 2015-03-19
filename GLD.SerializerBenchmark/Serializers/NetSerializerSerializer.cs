///
/// https://github.com/jsonfx/jsonfx
/// PM> Install-Package NetSerializer
///
using System;
using System.IO;
using NetSerializer;

namespace GLD.SerializerBenchmark
{
    internal class NetSerializerSerializer : ISerDeser
    {
        private readonly Serializer _serializer;
        public NetSerializerSerializer(Type type)
        {
            _serializer = new Serializer(new Type[] { type });
        }

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, (T)person);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T)_serializer.Deserialize(stream);
            }
        }

        #endregion
    }
}