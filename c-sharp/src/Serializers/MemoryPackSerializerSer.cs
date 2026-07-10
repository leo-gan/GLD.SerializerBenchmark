using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class MemoryPackSerializerSer : SerDeser
    {
        private object _native;
        private Type _nativeType;

        public override string Name => "MemoryPack";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _nativeType = MemoryPackTypeConverter.NativeTypeFor(serializablePrimaryType);
            _native = null;
        }

        public override void PrepareData(object data)
        {
            _native = MemoryPackTypeConverter.ToNative(data);
            _nativeType = _native?.GetType() ?? _nativeType;
        }

        public override string Serialize(object serializable)
        {
            var annotated = _native ?? MemoryPackTypeConverter.ToNative(serializable);
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(annotated.GetType(), annotated);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return MemoryPack.MemoryPackSerializer.Deserialize(_nativeType, bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var annotated = _native ?? MemoryPackTypeConverter.ToNative(serializable);
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(annotated.GetType(), annotated);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return MemoryPack.MemoryPackSerializer.Deserialize(_nativeType, ms.ToArray());
        }

        public override object ToDomain(object decoded) => MemoryPackTypeConverter.FromNative(decoded);
    }
}
