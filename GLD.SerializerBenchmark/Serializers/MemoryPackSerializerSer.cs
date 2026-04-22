using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // MemoryPack
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";

        public override bool Supports(string testDataName)
        {
            // MemoryPack works with annotated types: Integer, SimpleObject, StringArray
            return testDataName == "Integer" || testDataName == "SimpleObject" || testDataName == "StringArray";
        }

        public override string Serialize(object serializable)
        {
            // Convert to annotated type and serialize
            object annotated = ConvertToAnnotated(serializable);
            return Convert.ToBase64String(MemoryPack.MemoryPackSerializer.Serialize(annotated.GetType(), annotated));
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            // Deserialize annotated type and convert back
            object annotated = DeserializeAnnotated(bytes);
            return ConvertFromAnnotated(annotated);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            object annotated = ConvertToAnnotated(serializable);
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(annotated.GetType(), annotated);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            object annotated = DeserializeAnnotated(ms.ToArray());
            return ConvertFromAnnotated(annotated);
        }

        private object ConvertToAnnotated(object obj)
        {
            if (_primaryType == typeof(int))
                return MemoryPackTypeConverter.ToMemoryPack((int)obj);
            if (_primaryType == typeof(SimpleObject))
                return MemoryPackTypeConverter.ToMemoryPack((SimpleObject)obj);
            if (_primaryType == typeof(StringArrayObject))
                return MemoryPackTypeConverter.ToMemoryPack((StringArrayObject)obj);
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
            return annotated;
        }
    }
}
