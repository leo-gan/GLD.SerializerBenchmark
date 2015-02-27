///
/// See here https://github.com/mgravell/protobuf-net
/// >PM Install-Package protobuf-net
///     NOTE: I use the protobuf-net NuGet package because of
///     [http://stackoverflow.com/questions/2522376/how-to-choose-between-protobuf-csharp-port-and-protobuf-net]
/// 

using System;
using System.IO;
using ProtoBuf;

namespace GLD.SerializerBenchmark
{
     internal class ProtoBufSerializer : ISerDeser
    {
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
                return Serializer.Deserialize<T>(stream);
            }
        }

        #endregion
    }
}