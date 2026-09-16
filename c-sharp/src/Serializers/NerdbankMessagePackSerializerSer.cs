using System;
using System.Collections.Generic;
using System.IO;
using Nerdbank.MessagePack;
using PolyType;
using PolyType.ReflectionProvider;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Nerdbank.MessagePack with reflection-based shapes and stable numeric
    /// member keys on the suite POCOs.
    /// https://github.com/AArnott/Nerdbank.MessagePack
    /// </summary>
    internal class NerdbankMessagePackSerializerSer : SerDeser
    {
        private static readonly MessagePackSerializer Serializer = new();

        private ITypeShape _shape;

        public override string Name => "Nerdbank.MessagePack";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);

            // We would prefer to use source generation for better performance, but this adapter
            // offers no generic type context which source generated type shape retrieval requires.
            _shape = ReflectionTypeShapeProvider.Default.GetTypeShape(serializablePrimaryType)
                ?? throw new NotSupportedException($"No reflection type shape is available for {serializablePrimaryType}.");
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(Serializer.SerializeObject(serializable, _shape));

        public override object Deserialize(string serialized)
            => Serializer.DeserializeObject(Convert.FromBase64String(serialized), _shape);

        public override void Serialize(object serializable, Stream outputStream)
            => Serializer.SerializeObject(outputStream, serializable, _shape);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return Serializer.DeserializeObject(inputStream, _shape);
        }
    }
}
