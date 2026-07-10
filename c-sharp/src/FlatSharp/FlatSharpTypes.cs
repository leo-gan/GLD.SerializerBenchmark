using System.Collections.Generic;
using FlatSharp.Attributes;

namespace GLD.SerializerBenchmark.FShrp
{
    [FlatBufferTable]
    public class SimpleObject
    {
        [FlatBufferItem(0)] public virtual int Id { get; set; }
        [FlatBufferItem(1)] public virtual string Name { get; set; }
        [FlatBufferItem(2)] public virtual long Timestamp { get; set; }
        [FlatBufferItem(3)] public virtual bool IsActive { get; set; }
    }

    [FlatBufferTable]
    public class StringArrayObject
    {
        [FlatBufferItem(0)] public virtual IList<string> Items { get; set; }
    }

    [FlatBufferTable]
    public class ServiceLine
    {
        [FlatBufferItem(0)] public virtual string ServiceCode { get; set; }
        [FlatBufferItem(1)] public virtual double ChargeAmount { get; set; }
        [FlatBufferItem(2)] public virtual double AdjudicatedAmount { get; set; }
    }

    [FlatBufferTable]
    public class Claim
    {
        [FlatBufferItem(0)] public virtual string ClaimId { get; set; }
        [FlatBufferItem(1)] public virtual string PatientName { get; set; }
        [FlatBufferItem(2)] public virtual double TotalCharge { get; set; }
        [FlatBufferItem(3)] public virtual double PaymentAmount { get; set; }
        [FlatBufferItem(4)] public virtual IList<ServiceLine> Lines { get; set; }
    }

    [FlatBufferTable]
    public class EDI835
    {
        [FlatBufferItem(0)] public virtual string PayerName { get; set; }
        [FlatBufferItem(1)] public virtual string PayeeName { get; set; }
        [FlatBufferItem(2)] public virtual long PaymentDate { get; set; }
        [FlatBufferItem(3)] public virtual double TotalActualAmount { get; set; }
        [FlatBufferItem(4)] public virtual string TransactionControlNumber { get; set; }
        [FlatBufferItem(5)] public virtual IList<Claim> Claims { get; set; }
    }

    [FlatBufferTable]
    public class TelemetryData
    {
        [FlatBufferItem(0)] public virtual string Id { get; set; }
        [FlatBufferItem(1)] public virtual string DataSource { get; set; }
        [FlatBufferItem(2)] public virtual long TimeStamp { get; set; }
        [FlatBufferItem(3)] public virtual int Param1 { get; set; }
        [FlatBufferItem(4)] public virtual uint Param2 { get; set; }
        [FlatBufferItem(5)] public virtual IList<double> Measurements { get; set; }
        [FlatBufferItem(6)] public virtual long AssociatedProblemID { get; set; }
        [FlatBufferItem(7)] public virtual long AssociatedLogID { get; set; }
        [FlatBufferItem(8)] public virtual bool WasProcessed { get; set; }
    }

    [FlatBufferTable]
    public class SimpleObjectBatch
    {
        [FlatBufferItem(0)] public virtual IList<SimpleObject> Items { get; set; }
    }

    [FlatBufferTable]
    public class StringArrayObjectBatch
    {
        [FlatBufferItem(0)] public virtual IList<StringArrayObject> Items { get; set; }
    }

    [FlatBufferTable]
    public class EDI835Batch
    {
        [FlatBufferItem(0)] public virtual IList<EDI835> Items { get; set; }
    }

    [FlatBufferTable]
    public class TelemetryDataBatch
    {
        [FlatBufferItem(0)] public virtual IList<TelemetryData> Items { get; set; }
    }
}
