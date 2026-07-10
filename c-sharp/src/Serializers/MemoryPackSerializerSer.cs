using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // MemoryPack — convert to [MemoryPackable] models in PrepareData (untimed).
    // Timed path: Serialize(annotated) only. ToDomain converts back after deser.
    // https://github.com/Cysharp/MemoryPack
    internal class MemoryPackSerializerSer : SerDeser
    {
        private object _native; // annotated model
        private Type _nativeType;

        public override string Name => "MemoryPack";

        public override bool Supports(string testDataName) =>
            testDataName is "Integer" or "SimpleObject" or "StringArray" or "ObjectGraph"
            or "message" or "event" or "strings";

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
            if (_primaryType == typeof(int))
                return MemoryPackTypeConverter.ToMemoryPack((int)obj);
            if (_primaryType == typeof(SimpleObject))
                return MemoryPackTypeConverter.ToMemoryPack((SimpleObject)obj);
            if (_primaryType == typeof(StringArrayObject))
                return MemoryPackTypeConverter.ToMemoryPack((StringArrayObject)obj);
            if (_primaryType == typeof(ObjectGraph))
                return MemoryPackTypeConverter.ToMemoryPack((ObjectGraph)obj);
            return obj;
        }

        private object DeserializeAnnotated(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.IntObject>(bytes);
            if (_primaryType == typeof(SimpleObject))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.SimpleObject>(bytes);
            if (_primaryType == typeof(StringArrayObject))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.StringArrayObject>(bytes);
            if (_primaryType == typeof(ObjectGraph))
                return global::MemoryPack.MemoryPackSerializer.Deserialize<MPack.ObjectGraph>(bytes);
            return null;
        }

        private object ConvertFromAnnotated(object annotated)
        {
            if (annotated is MPack.IntObject intObj)
                return MemoryPackTypeConverter.FromMemoryPack(intObj);
            if (annotated is MPack.SimpleObject simpleObj)
                return MemoryPackTypeConverter.FromMemoryPack(simpleObj);
            if (annotated is MPack.StringArrayObject arrayObj)
                return MemoryPackTypeConverter.FromMemoryPack(arrayObj);
            if (annotated is MPack.ObjectGraph graph)
                return MemoryPackTypeConverter.FromMemoryPack(graph);
            return annotated;
        }
    }
}
