/// SharpSerializer (Polenter) wrapper for .NET 8.
///
/// Two net8.0 fixes on top of stock Polenter 3.0.2:
/// 1) DefaultInstanceCreator throws MissingMethodException for types that have
///    parameterless constructors; we inject Activator-based IInstanceCreator.
/// 2) ArrayAnalyzer NREs on every T[] under net8; TelemetryData.Measurements is
///    double[], so we map to List&lt;double&gt; untimed (still pure SharpSerializer of
///    an equivalent shape). Other V2 types use List or scalars and need no map.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Polenter.Serialization;
using Polenter.Serialization.Core;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>Uses Activator — Polenter's default creator is broken under net8.0.</summary>
    internal sealed class ActivatorInstanceCreator : IInstanceCreator
    {
        public object CreateInstance(Type type)
        {
            if (type == null)
                throw new ArgumentNullException(nameof(type));
            return Activator.CreateInstance(type, nonPublic: true)
                   ?? throw new InvalidOperationException(
                       $"Activator could not create instance of {type.FullName}");
        }
    }

    /// <summary>
    /// TelemetryData with Measurements as List (Polenter net8 cannot walk T[]).
    /// </summary>
    public class TelemetrySsDto
    {
        public TelemetrySsDto() { }

        public long AssociatedLogID { get; set; }
        public long AssociatedProblemID { get; set; }
        public string DataSource { get; set; }
        public string Id { get; set; }
        public List<double> Measurements { get; set; }
        public int Param1 { get; set; }
        public uint Param2 { get; set; }
        public DateTime TimeStamp { get; set; }
        public bool WasProcessed { get; set; }

        public static TelemetrySsDto FromDomain(TelemetryData d)
        {
            if (d == null) return null;
            return new TelemetrySsDto
            {
                AssociatedLogID = d.AssociatedLogID,
                AssociatedProblemID = d.AssociatedProblemID,
                DataSource = d.DataSource,
                Id = d.Id,
                Measurements = d.Measurements == null ? null : d.Measurements.ToList(),
                Param1 = d.Param1,
                Param2 = d.Param2,
                TimeStamp = d.TimeStamp,
                WasProcessed = d.WasProcessed,
            };
        }

        public TelemetryData ToDomain()
        {
            return new TelemetryData
            {
                AssociatedLogID = AssociatedLogID,
                AssociatedProblemID = AssociatedProblemID,
                DataSource = DataSource,
                Id = Id,
                Measurements = Measurements == null ? null : Measurements.ToArray(),
                Param1 = Param1,
                Param2 = Param2,
                TimeStamp = TimeStamp,
                WasProcessed = WasProcessed,
            };
        }
    }

    internal class SharpSerializer : SerDeser
    {
        private static readonly IInstanceCreator InstanceCreator = new ActivatorInstanceCreator();

        private Polenter.Serialization.SharpSerializer _serializer;
        private object _native; // domain object, or TelemetrySsDto for telemetry

        private static Polenter.Serialization.SharpSerializer CreateSerializer()
        {
            var settings = new SharpSerializerXmlSettings
            {
                IncludeAssemblyVersionInTypeName = false,
                IncludeCultureInTypeName = false,
                IncludePublicKeyTokenInTypeName = false,
                InstanceCreator = InstanceCreator,
            };
            return new Polenter.Serialization.SharpSerializer(settings);
        }

        public override string Name => "SharpSerializer";

        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serializer = CreateSerializer();
            _native = null;
        }

        public override void PrepareData(object data)
        {
            _serializer ??= CreateSerializer();
            _native = ToNative(data);
            // Untimed warm-up: prove ser/deser with the net8 fixes.
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(_native, ms);
                ms.Position = 0;
                _ = _serializer.Deserialize(ms);
            }
        }

        public override object ToDomain(object decoded)
        {
            if (decoded is TelemetrySsDto dto)
                return dto.ToDomain();
            if (decoded is List<TelemetrySsDto> list)
                return list.Select(x => x.ToDomain()).ToList();
            return decoded;
        }

        private static object ToNative(object data)
        {
            if (data is TelemetryData td)
                return TelemetrySsDto.FromDomain(td);
            if (data is List<TelemetryData> list)
                return list.Select(TelemetrySsDto.FromDomain).ToList();
            return data;
        }

        public override string Serialize(object serializable)
        {
            var ser = _serializer ?? CreateSerializer();
            var payload = _native ?? ToNative(serializable);
            using (var ms = new MemoryStream())
            {
                ser.Serialize(payload, ms);
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var ser = _serializer ?? CreateSerializer();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
                return ser.Deserialize(stream);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var payload = _native ?? ToNative(serializable);
            (_serializer ?? CreateSerializer()).Serialize(payload, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Seek(0, SeekOrigin.Begin);
            return (_serializer ?? CreateSerializer()).Deserialize(inputStream);
        }
    }
}
