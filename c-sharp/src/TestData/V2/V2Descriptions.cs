// Fallback N=1 fixtures when resolve_run_config is unavailable.
using System;
using System.Collections.Generic;
using System.Text.Json;

namespace GLD.SerializerBenchmark.TestData.V2
{
    static class FallbackConfig
    {
        public static JsonElement Empty => default;
    }

    public sealed class MessageDescription : ITestDataDescription
    {
        private readonly Message _data;
        public MessageDescription(int seed = 42)
        {
            _data = (Message)Generator.MakeOne("message", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "message";
        public string Description => "v2 message";
        public Type DataType => typeof(Message);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class DocumentDescription : ITestDataDescription
    {
        private readonly Document _data;
        public DocumentDescription(int seed = 42)
        {
            _data = (Document)Generator.MakeOne("document", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "document";
        public string Description => "v2 document";
        public Type DataType => typeof(Document);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(DocumentMeta), typeof(DocumentItem) };
        public object Data => _data;
    }

    public sealed class TelemetryV2Description : ITestDataDescription
    {
        private readonly Telemetry _data;
        public TelemetryV2Description(int seed = 42)
        {
            _data = (Telemetry)Generator.MakeOne("telemetry", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "telemetry";
        public string Description => "v2 telemetry";
        public Type DataType => typeof(Telemetry);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class StringsDescription : ITestDataDescription
    {
        private readonly Strings _data;
        public StringsDescription(int seed = 42)
        {
            _data = (Strings)Generator.MakeOne("strings", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "strings";
        public string Description => "v2 strings";
        public Type DataType => typeof(Strings);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class EventDescription : ITestDataDescription
    {
        private readonly Event _data;
        public EventDescription(int seed = 42)
        {
            _data = (Event)Generator.MakeOne("event", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "event";
        public string Description => "v2 event";
        public Type DataType => typeof(Event);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(EventAttr) };
        public object Data => _data;
    }

    // Columnar ids. Not added to Program's fallback list or Exporter: old smoke
    // must keep constructing only message and telemetry.
    public sealed class TableDescription : ITestDataDescription
    {
        private readonly TableRow _data;
        public TableDescription(int seed = 42)
        {
            _data = (TableRow)Generator.MakeOne("table", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "table";
        public string Description => "v2 table";
        public Type DataType => typeof(TableRow);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class TableProjectDescription : ITestDataDescription
    {
        private readonly TableRow _data;
        public TableProjectDescription(int seed = 42)
        {
            _data = (TableRow)Generator.MakeOne("table_project", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "table_project";
        public string Description => "v2 table_project";
        public Type DataType => typeof(TableRow);
        public List<Type> SecondaryDataTypes => new List<Type>();
        public object Data => _data;
    }

    public sealed class NestedTableDescription : ITestDataDescription
    {
        private readonly NestedRow _data;
        public NestedTableDescription(int seed = 42)
        {
            _data = (NestedRow)Generator.MakeOne("nested_table", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "nested_table";
        public string Description => "v2 nested_table";
        public Type DataType => typeof(NestedRow);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(NestedMeta), typeof(NestedItem) };
        public object Data => _data;
    }

    public sealed class SignalDescription : ITestDataDescription
    {
        private readonly Signal _data;
        public SignalDescription(int seed = 42)
        {
            _data = (Signal)Generator.MakeOne("signal", FallbackConfig.Empty, seed, 0);
        }
        public string Name => "signal";
        public string Description => "v2 signal";
        public Type DataType => typeof(Signal);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(SignalLeg) };
        public object Data => _data;
    }
}
