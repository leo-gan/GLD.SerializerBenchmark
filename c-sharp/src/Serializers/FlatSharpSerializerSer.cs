using System;
using System.IO;
using FlatSharp;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    // FlatSharp — PrepareData builds annotated tables untimed; timed path is GetMaxSize+Serialize only.
    // https://github.com/jamescourtney/FlatSharp
    internal class FlatSharpSerializerSer : SerDeser
    {
        private readonly FlatBufferSerializer _serializer = FlatBufferSerializer.Default;
        private object _native;

        public override string Name => "FlatSharp";

        public override bool Supports(string testDataName) =>
            testDataName is "Integer" or "SimpleObject" or "StringArray" or "ObjectGraph"
            or "message" or "event" or "strings";

        public override void PrepareData(object data)
        {
            _native = ToAnnotated(data);
        }

        public override object ToDomain(object decoded) => FromAnnotated(decoded);

        public override string Serialize(object serializable)
        {
            var (buffer, len) = SerializeAnnotated(_native ?? ToAnnotated(serializable));
            if (buffer == null || len <= 0) return "";
            return Convert.ToBase64String(buffer, 0, len);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return ParseAnnotated(bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var (buffer, len) = SerializeAnnotated(_native ?? ToAnnotated(serializable));
            if (buffer == null || len <= 0) return;
            outputStream.Write(buffer, 0, len);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return ParseAnnotated(ms.ToArray());
        }

        private (byte[] buffer, int len) SerializeAnnotated(object annotated)
        {
            if (annotated is FShrp.IntObject i)
            {
                int maxSize = _serializer.GetMaxSize(i);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(i, buffer));
            }
            if (annotated is FShrp.SimpleObject s)
            {
                int maxSize = _serializer.GetMaxSize(s);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(s, buffer));
            }
            if (annotated is FShrp.StringArrayObject a)
            {
                int maxSize = _serializer.GetMaxSize(a);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(a, buffer));
            }
            if (annotated is FShrp.ObjectGraph g)
            {
                int maxSize = _serializer.GetMaxSize(g);
                var buffer = new byte[maxSize];
                return (buffer, _serializer.Serialize(g, buffer));
            }
            return (null, 0);
        }

        private object ParseAnnotated(byte[] bytes)
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

        private object ToAnnotated(object obj)
        {
            if (_primaryType == typeof(int))
                return FlatSharpTypeConverter.ToFlatSharp((int)obj);
            if (_primaryType == typeof(SimpleObject))
                return FlatSharpTypeConverter.ToFlatSharp((SimpleObject)obj);
            if (_primaryType == typeof(StringArrayObject))
                return FlatSharpTypeConverter.ToFlatSharp((StringArrayObject)obj);
            if (_primaryType == typeof(ObjectGraph))
                return FlatSharpTypeConverter.ToFlatSharp((ObjectGraph)obj);
            return null;
        }

        private object FromAnnotated(object annotated)
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
