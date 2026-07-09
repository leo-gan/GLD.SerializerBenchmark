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
            // FlatSharp works with annotated types (+ flat ObjectGraph)
            return testDataName is "Integer" or "SimpleObject" or "StringArray" or "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            var (buffer, len) = SerializeToBuffer(serializable);
            if (buffer == null || len <= 0) return "";
            return Convert.ToBase64String(buffer, 0, len);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            object annotated = DeserializeAnnotated(bytes);
            return ConvertFromAnnotated(annotated);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var (buffer, len) = SerializeToBuffer(serializable);
            if (buffer == null || len <= 0) return;
            outputStream.Write(buffer, 0, len);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            object annotated = DeserializeAnnotated(ms.ToArray());
            return ConvertFromAnnotated(annotated);
        }


        /// <summary>
        /// FlatSharp APIs are generic; boxing as object loses the type model (System.Object error).
        /// Keep strongly-typed Serialize/GetMaxSize overloads.
        /// </summary>
        private (byte[] buffer, int len) SerializeToBuffer(object serializable)
        {
            if (_primaryType == typeof(int))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((int)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(annotated, buffer));
            }
            if (_primaryType == typeof(SimpleObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((SimpleObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(annotated, buffer));
            }
            if (_primaryType == typeof(StringArrayObject))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((StringArrayObject)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(annotated, buffer));
            }
            if (_primaryType == typeof(ObjectGraph))
            {
                var annotated = FlatSharpTypeConverter.ToFlatSharp((ObjectGraph)serializable);
                int maxSize = _serializer.GetMaxSize(annotated);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(annotated, buffer));
            }
            return (null, 0);
        }

        private object DeserializeAnnotated(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return _serializer.Parse<FShrp.IntObject>(bytes);
            if (_primaryType == typeof(SimpleObject))
                return _serializer.Parse<FShrp.SimpleObject>(bytes);
            if (_primaryType == typeof(StringArrayObject))
                return _serializer.Parse<FShrp.StringArrayObject>(bytes);
            if (_primaryType == typeof(ObjectGraph))
                return _serializer.Parse<FShrp.ObjectGraph>(bytes);
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
            if (annotated is FShrp.ObjectGraph graph)
                return FlatSharpTypeConverter.FromFlatSharp(graph);
            return annotated;
        }
    }
}
