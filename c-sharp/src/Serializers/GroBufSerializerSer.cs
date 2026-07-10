using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using GroBuf;
using GroBuf.DataMembersExtracters;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// GroBuf: single Serializer + PropertiesExtractor + WriteEmptyObjects.
    /// Typed Serialize&lt;T&gt; via <see cref="TypedSer"/> bind on _primaryType — no suite types.
    /// https://github.com/skbkontur/GroBuf
    /// </summary>
    internal class GroBufSerializerSer : SerDeser
    {
        private readonly Serializer _serializer = new Serializer(
            new PropertiesExtractor(),
            options: GroBufOptions.WriteEmptyObjects);

        private Func<object, byte[]> _serBytes;

        public override string Name => "GroBuf";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var open = typeof(Serializer).GetMethods(BindingFlags.Public | BindingFlags.Instance)
                .First(m => m.Name == "Serialize" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 1);
            _serBytes = TypedSer.BindSerializeBytes(serializablePrimaryType, open, _serializer);
            // Warm code-gen (untimed)
            try
            {
                var sample = Activator.CreateInstance(serializablePrimaryType);
                if (sample != null) _ = _serBytes(sample);
            }
            catch { /* best-effort warm */ }
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(_serBytes(serializable));

        public override object Deserialize(string serialized)
            => _serializer.Deserialize(_primaryType, Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = _serBytes(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Deserialize(_primaryType, ms.ToArray());
        }
    }
}
