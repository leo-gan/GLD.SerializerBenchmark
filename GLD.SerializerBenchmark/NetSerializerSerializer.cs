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
        public NetSerializerSerializer(Type type)
        {
            Serializer.Initialize(new Type[] {type});
        }

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                Serializer.Serialize(ms, (T)person);
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
                return (T)Serializer.Deserialize(stream);
            }
        }

        #endregion
    }
}