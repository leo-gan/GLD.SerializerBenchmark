using System;
using System.IO;
using Polenter.Serialization;
using Polenter.Serialization.Core;

namespace GLD.SerializerBenchmark.Serializers
{
    internal sealed class ActivatorInstanceCreator : IInstanceCreator
    {
        public object CreateInstance(Type type) =>
            Activator.CreateInstance(type, nonPublic: true)
            ?? throw new InvalidOperationException($"Cannot create {type}");
    }

    internal class SharpSerializer : SerDeser
    {
        private static readonly IInstanceCreator Creator = new ActivatorInstanceCreator();
        private Polenter.Serialization.SharpSerializer _serializer;

        public override string Name => "SharpSerializer";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serializer = new Polenter.Serialization.SharpSerializer(new SharpSerializerXmlSettings
            {
                IncludeAssemblyVersionInTypeName = false,
                IncludeCultureInTypeName = false,
                IncludePublicKeyTokenInTypeName = false,
                InstanceCreator = Creator,
            });
        }

        public override string Serialize(object serializable)
        {
            using var ms = new MemoryStream();
            _serializer.Serialize(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized)
        {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize(ms);
        }

        public override void Serialize(object serializable, Stream outputStream)
            => _serializer.Serialize(serializable, outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }
    }
}
