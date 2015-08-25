///
/// https://github.com/tomba/netserializer
/// PM> Install-Package NetSerializer
///
using System;
using System.Collections.Generic;
using System.IO;
using NetSerializer;

namespace GLD.SerializerBenchmark
{
    internal class NetSerializerSerializer : ISerDeser
    {
        private readonly Serializer _serializer;
        public NetSerializerSerializer(IEnumerable<Type> types)
        {
            _serializer = new Serializer(types);
        }

        #region ISerDeser Members

        public string Name {get { return "NetSerializer"; } }

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

        public void Serialize<T>(object person, Stream outputStream)
        {
             _serializer.Serialize(outputStream, (T)person);
        }


        public T Deserialize<T>(Stream inputStream)
        {
                return (T)_serializer.Deserialize(inputStream);
        }

        #endregion
    }
}