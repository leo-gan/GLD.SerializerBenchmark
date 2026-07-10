using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using BinaryPack;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// BinaryPack: BinaryConverter.Serialize/Deserialize&lt;T&gt; bound from primary type only.
    /// https://github.com/Sergio0694/BinaryPack
    /// </summary>
    internal class BinaryPackSerializerSer : SerDeser
    {
        private Func<object, byte[]> _serBytes;
        private Func<byte[], object> _deserBytes;
        private Action<object, Stream> _serStream;
        private Func<Stream, object> _deserStream;

        public override string Name => "BinaryPack";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var t = serializablePrimaryType;
            var serBytes = typeof(BinaryConverter).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                            && m.ReturnType == typeof(byte[]) && m.GetParameters().Length == 1);
            var deserBytes = typeof(BinaryConverter).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 1
                            && m.GetParameters()[0].ParameterType == typeof(byte[]));
            var serStream = typeof(BinaryConverter).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                            && m.ReturnType == typeof(void) && m.GetParameters().Length == 2
                            && m.GetParameters()[1].ParameterType == typeof(Stream));
            var deserStream = typeof(BinaryConverter).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "Deserialize" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 1
                            && m.GetParameters()[0].ParameterType == typeof(Stream));

            _serBytes = TypedSer.BindSerializeBytes(t, serBytes);
            _deserBytes = TypedSer.BindDeserializeBytes(t, deserBytes);
            _serStream = TypedSer.BindSerializeStream(t, serStream);
            _deserStream = TypedSer.BindDeserializeStream(t, deserStream);
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(_serBytes(serializable));

        public override object Deserialize(string serialized)
            => _deserBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
            => _serStream(serializable, outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _deserStream(inputStream);
        }
    }
}
