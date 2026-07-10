using System;
using System.Collections.Generic;
using MemoryPack;

namespace GLD.SerializerBenchmark.MPack
{
    [MemoryPackable]
    public partial class SimpleObject
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public DateTime Timestamp { get; set; }
        public bool IsActive { get; set; }
    }

    [MemoryPackable]
    public partial class StringArrayObject
    {
        public List<string> Items { get; set; }
    }

    [MemoryPackable]
    public partial class ServiceLine
    {
        public string ServiceCode { get; set; }
        public double ChargeAmount { get; set; }
        public double AdjudicatedAmount { get; set; }
    }

    [MemoryPackable]
    public partial class Claim
    {
        public string ClaimId { get; set; }
        public string PatientName { get; set; }
        public double TotalCharge { get; set; }
        public double PaymentAmount { get; set; }
        public List<ServiceLine> Lines { get; set; }
    }

    [MemoryPackable]
    public partial class EDI835
    {
        public string PayerName { get; set; }
        public string PayeeName { get; set; }
        public DateTime PaymentDate { get; set; }
        public double TotalActualAmount { get; set; }
        public string TransactionControlNumber { get; set; }
        public List<Claim> Claims { get; set; }
    }

    [MemoryPackable]
    public partial class TelemetryData
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
    }

    [MemoryPackable]
    public partial class SimpleObjectBatch
    {
        public List<SimpleObject> Items { get; set; }
    }

    [MemoryPackable]
    public partial class StringArrayObjectBatch
    {
        public List<StringArrayObject> Items { get; set; }
    }

    [MemoryPackable]
    public partial class EDI835Batch
    {
        public List<EDI835> Items { get; set; }
    }

    [MemoryPackable]
    public partial class TelemetryDataBatch
    {
        public List<TelemetryData> Items { get; set; }
    }
}
