// Hand-written Bond batch envelopes for N>1 cells (root must be a Bond schema type).
using System.Collections.Generic;
using Bond;

namespace GLD.SerializerBenchmark.Bond
{
    [Schema]
    public class SimpleObjectBatch
    {
        public SimpleObjectBatch() { Items = new List<SimpleObject>(); }
        [Id(0)] public List<SimpleObject> Items { get; set; }
    }

    [Schema]
    public class StringArrayObjectBatch
    {
        public StringArrayObjectBatch() { Items = new List<StringArrayObject>(); }
        [Id(0)] public List<StringArrayObject> Items { get; set; }
    }

    [Schema]
    public class TelemetryDataBatch
    {
        public TelemetryDataBatch() { Items = new List<TelemetryData>(); }
        [Id(0)] public List<TelemetryData> Items { get; set; }
    }

    [Schema]
    public class EDI835Batch
    {
        public EDI835Batch() { Items = new List<EDI835>(); }
        [Id(0)] public List<EDI835> Items { get; set; }
    }
}
