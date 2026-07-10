using System;
using System.IO;
using FlatSharp;
using GLD.SerializerBenchmark.TestData;
using F = GLD.SerializerBenchmark.FShrp;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class FlatSharpSerializerSer : SerDeser
    {
        private readonly FlatBufferSerializer _serializer = FlatBufferSerializer.Default;
        private object _native;
        private Type _nativeType;

        public override string Name => "FlatSharp";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _nativeType = FlatSharpTypeConverter.NativeTypeFor(serializablePrimaryType);
            _native = null;
        }

        public override void PrepareData(object data)
        {
            _native = FlatSharpTypeConverter.ToNative(data);
            _nativeType = _native?.GetType() ?? _nativeType;
        }

        public override object ToDomain(object decoded) => FlatSharpTypeConverter.FromNative(decoded);

        public override string Serialize(object serializable)
        {
            var (buffer, len) = SerializeAnnotated(_native ?? FlatSharpTypeConverter.ToNative(serializable));
            if (buffer == null || len <= 0) return "";
            return Convert.ToBase64String(buffer, 0, len);
        }

        public override object Deserialize(string serialized)
        {
            return ParseAnnotated(Convert.FromBase64String(serialized));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var (buffer, len) = SerializeAnnotated(_native ?? FlatSharpTypeConverter.ToNative(serializable));
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
            switch (annotated)
            {
                case F.SimpleObject s: return Ser(s);
                case F.StringArrayObject a: return Ser(a);
                case F.EDI835 d: return Ser(d);
                case F.TelemetryData t: return Ser(t);
                case F.SimpleObjectBatch b: return Ser(b);
                case F.StringArrayObjectBatch b: return Ser(b);
                case F.EDI835Batch b: return Ser(b);
                case F.TelemetryDataBatch b: return Ser(b);
                default: return (null, 0);
            }
        }

        private (byte[] buffer, int len) Ser<T>(T item) where T : class
        {
            int max = _serializer.GetMaxSize(item);
            var buffer = new byte[max];
            int len = _serializer.Serialize(item, buffer);
            return (buffer, len);
        }

        private object ParseAnnotated(byte[] bytes)
        {
            if (_nativeType == typeof(F.SimpleObject)) return _serializer.Parse<F.SimpleObject>(bytes);
            if (_nativeType == typeof(F.StringArrayObject)) return _serializer.Parse<F.StringArrayObject>(bytes);
            if (_nativeType == typeof(F.EDI835)) return _serializer.Parse<F.EDI835>(bytes);
            if (_nativeType == typeof(F.TelemetryData)) return _serializer.Parse<F.TelemetryData>(bytes);
            if (_nativeType == typeof(F.SimpleObjectBatch)) return _serializer.Parse<F.SimpleObjectBatch>(bytes);
            if (_nativeType == typeof(F.StringArrayObjectBatch)) return _serializer.Parse<F.StringArrayObjectBatch>(bytes);
            if (_nativeType == typeof(F.EDI835Batch)) return _serializer.Parse<F.EDI835Batch>(bytes);
            if (_nativeType == typeof(F.TelemetryDataBatch)) return _serializer.Parse<F.TelemetryDataBatch>(bytes);
            return null;
        }
    }
}
