using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Apache.Fory;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    internal sealed class ForySerializerSer : SerDeser
    {
        private readonly Fory _fory = Fory.Builder().Build();
        private Func<object, byte[]> _encode;
        private Func<byte[], object> _decode;

        public ForySerializerSer()
        {
            _fory.Register<Message>(1);
            _fory.Register<DocumentMeta>(2);
            _fory.Register<DocumentItem>(3);
            _fory.Register<Document>(4);
            _fory.Register<Telemetry>(5);
            _fory.Register<Strings>(6);
            _fory.Register<EventAttr>(7);
            _fory.Register<Event>(8);
            _fory.Register<BatchMessage>(9);
            _fory.Register<BatchDocument>(10);
            _fory.Register<BatchTelemetry>(11);
            _fory.Register<BatchStrings>(12);
            _fory.Register<BatchEvent>(13);
        }

        public override string Name => "fory";
        public override string Version => PackageVersion.Of(typeof(Fory));
        public override string StreamMode => "adapted";

        public override void Initialize(Type type, List<Type> secondaryTypes = null)
        {
            base.Initialize(type, secondaryTypes);
            // Bind the generated, concrete serializer outside measurement.
            typeof(ForySerializerSer).GetMethod(nameof(Bind), BindingFlags.NonPublic | BindingFlags.Instance)
                .MakeGenericMethod(type).Invoke(this, null);
        }

        private void Bind<T>()
        {
            _encode = value => _fory.Serialize((T)value);
            _decode = bytes => _fory.Deserialize<T>(bytes);
        }

        public override void PrepareData(object data) => _decode(_encode(data));
        public override string Serialize(object value) => Convert.ToBase64String(_encode(value));
        public override object Deserialize(string value) => _decode(Convert.FromBase64String(value));
        public override void Serialize(object value, Stream output)
        {
            var bytes = _encode(value);
            output.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream input)
        {
            input.Position = 0;
            using var bytes = new MemoryStream();
            input.CopyTo(bytes);
            return _decode(bytes.ToArray());
        }
    }
}
