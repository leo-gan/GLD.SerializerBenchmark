// Data Model v2 fixtures. TestDataName is the v2 type_id.
// Payload POCOs are structural proxies under TestData/ (not V1 suite names).
using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark.TestData.V2
{
    public sealed class MessageDescription : ITestDataDescription
    {
        private readonly SimpleObject _data;
        public MessageDescription(int seed = 42)
        {
            var r = new Random(seed);
            _data = new SimpleObject
            {
                Id = r.Next(0, 1_000_000),
                Name = "msg-" + r.Next(1000, 9999),
                Timestamp = DateTime.UtcNow,
                IsActive = r.Next(0, 2) == 1
            };
        }
        public string Name => "message";
        public string Description => "v2 message (SimpleObject proxy)";
        public Type DataType => typeof(SimpleObject);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class DocumentDescription : ITestDataDescription
    {
        private readonly EDI835 _data;
        public DocumentDescription(int seed = 42)
        {
            _data = EDI835.Generate();
        }
        public string Name => "document";
        public string Description => "v2 document (EDI835 proxy)";
        public Type DataType => typeof(EDI835);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(Claim), typeof(ServiceLine) };
        public object Data => _data;
    }

    public sealed class TelemetryV2Description : ITestDataDescription
    {
        private readonly TelemetryData _data;
        public TelemetryV2Description(int seed = 42)
        {
            _data = TelemetryData.Generate(Randomizer.Settings.CollectionOptions.TelemetryMeasurementsCount);
        }
        public string Name => "telemetry";
        public string Description => "v2 telemetry";
        public Type DataType => typeof(TelemetryData);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class StringsDescription : ITestDataDescription
    {
        private readonly StringArrayObject _data;
        public StringsDescription(int seed = 42)
        {
            _data = StringArrayObject.Generate(32);
        }
        public string Name => "strings";
        public string Description => "v2 strings";
        public Type DataType => typeof(StringArrayObject);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class EventDescription : ITestDataDescription
    {
        private readonly SimpleObject _data;
        public EventDescription(int seed = 42)
        {
            var r = new Random(seed + 7);
            _data = new SimpleObject
            {
                Id = r.Next(0, 1_000_000),
                Name = "evt-" + r.Next(1000, 9999),
                Timestamp = DateTime.UtcNow,
                IsActive = true
            };
        }
        public string Name => "event";
        public string Description => "v2 event (SimpleObject proxy)";
        public Type DataType => typeof(SimpleObject);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }
}
