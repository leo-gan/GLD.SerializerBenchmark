using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // MemoryPack — convert to [MemoryPackable] models in PrepareData (untimed).
    // Timed path: Serialize(annotated) only. ToDomain converts back after deser.
    internal class MemoryPackSerializerSer : SerDeser
    {
        private object _native;
        private Type _nativeType;

        public override string Name => "MemoryPack";

        // V2: message/event (SimpleObject), strings (StringArrayObject)
        public override bool Supports(string testDataName) =>
            testDataName is "message" or "event" or "strings";

        public override void PrepareData(object data)
        {
            _native = ConvertToAnnotated(data);
            _nativeType = _native?.GetType();
        }

        public override string Serialize(object serializable)
        {
            var annotated = _native ?? ConvertToAnnotated(serializable);
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(_nativeType ?? annotated.GetType(), annotated);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return DeserializeAnnotated(bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var annotated = _native ?? ConvertToAnnotated(serializable);
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(_nativeType ?? annotated.GetType(), annotated);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return DeserializeAnnotated(ms.ToArray());
        }

        public override object ToDomain(object decoded) => ConvertFromAnnotated(decoded);

        private object ConvertToAnnotated(object obj)
        {
            if (_primaryType == typeof(SimpleObject))
                return MemoryPackTypeConverter.ToMemoryPack((SimpleObject)obj);
            if (_primaryType == typeof(StringArrayObject))
                return MemoryPackTypeConverter.ToMemoryPack((StringArrayObject)obj);
            return obj;
        }

        private object DeserializeAnnotated(byte[] bytes)
        {
            if (_primaryType == typeof(SimpleObject))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.SimpleObject>(bytes);
            if (_primaryType == typeof(StringArrayObject))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.StringArrayObject>(bytes);
            return null;
        }

        private object ConvertFromAnnotated(object annotated)
        {
            if (annotated is MPack.SimpleObject simpleObj)
                return MemoryPackTypeConverter.FromMemoryPack(simpleObj);
            if (annotated is MPack.StringArrayObject arrayObj)
                return MemoryPackTypeConverter.FromMemoryPack(arrayObj);
            return annotated;
        }
    }
}
