using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // ZeroFormatter
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        public override string Name => "ZeroFormatter";

        public override bool Supports(string testDataName)
        {
            // ZeroFormatter works with annotated types: Integer, SimpleObject, StringArray
            return testDataName == "Integer" || testDataName == "SimpleObject" || testDataName == "StringArray";
        }

        public override string Serialize(object serializable)
        {
            object annotated = ConvertToAnnotated(serializable);
            return Convert.ToBase64String(ZeroFormatter.ZeroFormatterSerializer.Serialize(annotated));
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            object annotated = DeserializeAnnotated(bytes);
            return ConvertFromAnnotated(annotated);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            object annotated = ConvertToAnnotated(serializable);
            var bytes = ZeroFormatter.ZeroFormatterSerializer.Serialize(annotated);
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
                return ZeroFormatterTypeConverter.ToZeroFormatter((int)obj);
            if (_primaryType == typeof(SimpleObject))
                return ZeroFormatterTypeConverter.ToZeroFormatter((SimpleObject)obj);
            if (_primaryType == typeof(StringArrayObject))
                return ZeroFormatterTypeConverter.ToZeroFormatter((StringArrayObject)obj);
            return obj;
        }

        private object DeserializeAnnotated(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return global::ZeroFormatter.ZeroFormatterSerializer.Deserialize<ZFmt.IntObject>(bytes);
            if (_primaryType == typeof(SimpleObject))
                return global::ZeroFormatter.ZeroFormatterSerializer.Deserialize<ZFmt.SimpleObject>(bytes);
            if (_primaryType == typeof(StringArrayObject))
                return global::ZeroFormatter.ZeroFormatterSerializer.Deserialize<ZFmt.StringArrayObject>(bytes);
            return null;
        }

        private object ConvertFromAnnotated(object annotated)
        {
            if (annotated is ZFmt.IntObject intObj)
                return ZeroFormatterTypeConverter.FromZeroFormatter(intObj);
            if (annotated is ZFmt.SimpleObject simpleObj)
                return ZeroFormatterTypeConverter.FromZeroFormatter(simpleObj);
            if (annotated is ZFmt.StringArrayObject arrayObj)
                return ZeroFormatterTypeConverter.FromZeroFormatter(arrayObj);
            return annotated;
        }
    }
}
