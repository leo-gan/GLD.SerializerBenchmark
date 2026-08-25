using System;
using System.IO;
using MessagePack;
using MessagePack.Resolvers;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// MessagePack-CSharp (neuecc) — the usual .NET MessagePack library.
    /// Contractless resolver so suite POCOs need no extra attributes.
    /// https://github.com/MessagePack-CSharp/MessagePack-CSharp
    /// </summary>
    internal class MessagePackCSharpSerializerSer : SerDeser
    {
        private static readonly MessagePackSerializerOptions Options =
            MessagePackSerializerOptions.Standard.WithResolver(ContractlessStandardResolver.Instance);

        public override string Name => "MessagePack-CSharp";

        public override string Serialize(object serializable)
        {
            var bytes = MessagePackSerializer.Serialize(_primaryType, serializable, Options);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return MessagePackSerializer.Deserialize(_primaryType, bytes, Options);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            MessagePackSerializer.Serialize(_primaryType, outputStream, serializable, Options);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return MessagePackSerializer.Deserialize(_primaryType, inputStream, Options);
        }
    }
}
