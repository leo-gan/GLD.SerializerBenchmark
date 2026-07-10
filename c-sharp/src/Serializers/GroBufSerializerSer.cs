using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using GroBuf;
using GroBuf.DataMembersExtracters;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class GroBufSerializerSer : SerDeser
    {
        private readonly Serializer _serializer = new Serializer(new PropertiesExtractor());
        private object _native;
        private Type _serType;

        public override string Name => "GroBuf";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serType = serializablePrimaryType;
            _native = null;
        }

        public override void PrepareData(object data)
        {
            _native = ToNative(data);
            _serType = _native.GetType();
        }

        public override object ToDomain(object decoded) => FromNative(decoded);

        public override string Serialize(object serializable)
        {
            var payload = _native ?? ToNative(serializable);
            var bytes = SerializeTyped(payload);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            return _serializer.Deserialize(_serType, Convert.FromBase64String(serialized));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = SerializeTyped(_native ?? ToNative(serializable));
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Deserialize(_serType, ms.ToArray());
        }

        byte[] SerializeTyped(object payload)
        {
            // Prefer Serialize<T>(T) for correct type embedding
            var mi = typeof(Serializer).GetMethods()
                .First(m => m.Name == "Serialize" && m.IsGenericMethod && m.GetParameters().Length == 1);
            return (byte[])mi.MakeGenericMethod(payload.GetType()).Invoke(_serializer, new[] { payload });
        }

        static object ToNative(object data) => data switch
        {
            TelemetryData t => TelemetryDto.From(t),
            List<TelemetryData> lt => lt.Select(TelemetryDto.From).ToList(),
            StringArrayObject a => new StringDto { Items = a.Items?.ToArray() ?? Array.Empty<string>() },
            List<StringArrayObject> la => la.Select(a => new StringDto { Items = a.Items?.ToArray() ?? Array.Empty<string>() }).ToList(),
            _ => data
        };

        static object FromNative(object data) => data switch
        {
            TelemetryDto t => t.ToDomain(),
            List<TelemetryDto> lt => lt.Select(x => x.ToDomain()).ToList(),
            StringDto s => new StringArrayObject { Items = s.Items?.ToList() ?? new List<string>() },
            List<StringDto> ls => ls.Select(s => new StringArrayObject { Items = s.Items?.ToList() ?? new List<string>() }).ToList(),
            _ => data
        };

        public class StringDto { public string[] Items { get; set; } }

        public class TelemetryDto
        {
            public long AssociatedLogID { get; set; }
            public long AssociatedProblemID { get; set; }
            public string DataSource { get; set; }
            public string Id { get; set; }
            public List<double> Measurements { get; set; }
            public int Param1 { get; set; }
            public uint Param2 { get; set; }
            public DateTime TimeStamp { get; set; }
            public bool WasProcessed { get; set; }

            public static TelemetryDto From(TelemetryData t) => t == null ? null : new TelemetryDto
            {
                AssociatedLogID = t.AssociatedLogID,
                AssociatedProblemID = t.AssociatedProblemID,
                DataSource = t.DataSource,
                Id = t.Id,
                Measurements = t.Measurements?.ToList() ?? new List<double>(),
                Param1 = t.Param1,
                Param2 = t.Param2,
                TimeStamp = t.TimeStamp,
                WasProcessed = t.WasProcessed
            };

            public TelemetryData ToDomain() => new TelemetryData
            {
                AssociatedLogID = AssociatedLogID,
                AssociatedProblemID = AssociatedProblemID,
                DataSource = DataSource,
                Id = Id,
                Measurements = Measurements?.ToArray() ?? Array.Empty<double>(),
                Param1 = Param1,
                Param2 = Param2,
                TimeStamp = TimeStamp,
                WasProcessed = WasProcessed
            };
        }
    }
}
