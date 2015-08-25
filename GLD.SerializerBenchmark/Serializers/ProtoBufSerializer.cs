///
/// See here https://github.com/mgravell/protobuf-net
/// >PM Install-Package protobuf-net
///     NOTE: I use the protobuf-net NuGet package because of
///     [http://stackoverflow.com/questions/2522376/how-to-choose-between-protobuf-csharp-port-and-protobuf-net]
/// 

using System;
using System.IO;
using System.Runtime.Serialization;
using ProtoBuf;

namespace GLD.SerializerBenchmark
{
     internal class ProtoBufSerializer : ISerDeser
    {
         //public ProtoBufSerializer(Type type)
         //{
         //    var serializationInfo = new SerializationInfo(type, new FormatterConverter());
         //}
        #region ISerDeser Members

        public string Name {get { return "ProtoBuf"; } }

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

         public void Serialize<T>(object person, Stream outputStream)
         {
                Serializer.Serialize(outputStream, (T)person);
         }


         public T Deserialize<T>(Stream inputStream)
         {
                return Serializer.Deserialize<T>(inputStream);
         }

         #endregion
    }
}