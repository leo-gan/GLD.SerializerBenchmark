///
/// See here https://github.com/mgravell/protobuf-net
/// >PM Install-Package protobuf-net
///     NOTE: I use the protobuf-net NuGet package because of
///     [http://stackoverflow.com/questions/2522376/how-to-choose-between-protobuf-csharp-port-and-protobuf-net]
/// 

using System;
using System.IO;
using ProtoBuf;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ProtoBufSerializer : SerDeser
    {
        //public ProtoBufSerializer(Type type)
        //{
        //    var serializationInfo = new SerializationInfo(type, new FormatterConverter());
        //}

        #region ISerDeser Members

        public override string Name
        {
            get { return "ProtoBuf"; }
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                Serializer.Serialize(ms, serializable);
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
                return Serializer.Deserialize<object>(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return Serializer.Deserialize<object>(inputStream);
        }

        #endregion
    }
}