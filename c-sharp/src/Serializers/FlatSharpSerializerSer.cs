using System;
using System.IO;
using FlatSharp;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // FlatSharp
    internal class FlatSharpSerializerSer : SerDeser
    {
        private readonly FlatBufferSerializer _serializer = FlatBufferSerializer.Default;

        public override string Name => "FlatSharp";

        public override bool Supports(string testDataName)
        {
            // FlatSharp works with annotated types: Integer, SimpleObject, StringArray
            return testDataName == "Integer" || testDataName == "SimpleObject" || testDataName == "StringArray";
        }

        public override string Serialize(object serializable)
        {
            if (_primaryType == typeof(int))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((int)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                byte[] buffer = new byte[maxSize];
                int bytesWritten = _serializer.Serialize(annotated, buffer);
                return Convert.ToBase64String(buffer, 0, bytesWritten);
            }
            if (_primaryType == typeof(SimpleObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((SimpleObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                byte[] buffer = new byte[maxSize];
                int bytesWritten = _serializer.Serialize(annotated, buffer);
                return Convert.ToBase64String(buffer, 0, bytesWritten);
            }
            if (_primaryType == typeof(StringArrayObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((StringArrayObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                byte[] buffer = new byte[maxSize];
                int bytesWritten = _serializer.Serialize(annotated, buffer);
                return Convert.ToBase64String(buffer, 0, bytesWritten);
            }
            return "";
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            object annotated = DeserializeAnnotated(bytes);
            return ConvertFromAnnotated(annotated);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            byte[] buffer;
            int bytesWritten;
            if (_primaryType == typeof(int))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((int)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                buffer = new byte[maxSize];
                bytesWritten = _serializer.Serialize(annotated, buffer);
            }
            else if (_primaryType == typeof(SimpleObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((SimpleObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                buffer = new byte[maxSize];
                bytesWritten = _serializer.Serialize(annotated, buffer);
            }
            else if (_primaryType == typeof(StringArrayObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((StringArrayObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                buffer = new byte[maxSize];
                bytesWritten = _serializer.Serialize(annotated, buffer);
            }
            else return;
            outputStream.Write(buffer, 0, bytesWritten);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            object annotated = DeserializeAnnotated(ms.ToArray());
            return ConvertFromAnnotated(annotated);
        }


        private object DeserializeAnnotated(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return _serializer.Parse<FShrp.IntObject>(bytes);
            if (_primaryType == typeof(SimpleObject))
                return _serializer.Parse<FShrp.SimpleObject>(bytes);
            if (_primaryType == typeof(StringArrayObject))
                return _serializer.Parse<FShrp.StringArrayObject>(bytes);
            return null;
        }

        private object ConvertFromAnnotated(object annotated)
        {
            if (annotated is FShrp.IntObject intObj)
                return FlatSharpTypeConverter.FromFlatSharp(intObj);
            if (annotated is FShrp.SimpleObject simpleObj)
                return FlatSharpTypeConverter.FromFlatSharp(simpleObj);
            if (annotated is FShrp.StringArrayObject arrayObj)
                return FlatSharpTypeConverter.FromFlatSharp(arrayObj);
            return annotated;
        }
    }
}
