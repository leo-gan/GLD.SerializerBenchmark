using System;
using System.Collections.Generic;
using System.Linq;
using F = GLD.SerializerBenchmark.FShrp;

namespace GLD.SerializerBenchmark.TestData
{
    public static class FlatSharpTypeConverter
    {
        public static object ToNative(object data) => data switch
        {
            null => null,
            SimpleObject s => ToFlatSharp(s),
            StringArrayObject a => ToFlatSharp(a),
            EDI835 d => ToFlatSharp(d),
            TelemetryData t => ToFlatSharp(t),
            List<SimpleObject> ls => new F.SimpleObjectBatch { Items = ls.Select(ToFlatSharp).ToList() },
            List<StringArrayObject> la => new F.StringArrayObjectBatch { Items = la.Select(ToFlatSharp).ToList() },
            List<EDI835> ld => new F.EDI835Batch { Items = ld.Select(ToFlatSharp).ToList() },
            List<TelemetryData> lt => new F.TelemetryDataBatch { Items = lt.Select(ToFlatSharp).ToList() },
            _ => data
        };

        public static object FromNative(object data) => data switch
        {
            null => null,
            F.SimpleObject s => FromFlatSharp(s),
            F.StringArrayObject a => FromFlatSharp(a),
            F.EDI835 d => FromFlatSharp(d),
            F.TelemetryData t => FromFlatSharp(t),
            F.SimpleObjectBatch ls => ls.Items.Select(FromFlatSharp).ToList(),
            F.StringArrayObjectBatch la => la.Items.Select(FromFlatSharp).ToList(),
            F.EDI835Batch ld => ld.Items.Select(FromFlatSharp).ToList(),
            F.TelemetryDataBatch lt => lt.Items.Select(FromFlatSharp).ToList(),
            _ => data
        };

        public static Type NativeTypeFor(Type domainType)
        {
            if (domainType == typeof(SimpleObject)) return typeof(F.SimpleObject);
            if (domainType == typeof(StringArrayObject)) return typeof(F.StringArrayObject);
            if (domainType == typeof(EDI835)) return typeof(F.EDI835);
            if (domainType == typeof(TelemetryData)) return typeof(F.TelemetryData);
            if (domainType == typeof(List<SimpleObject>)) return typeof(F.SimpleObjectBatch);
            if (domainType == typeof(List<StringArrayObject>)) return typeof(F.StringArrayObjectBatch);
            if (domainType == typeof(List<EDI835>)) return typeof(F.EDI835Batch);
            if (domainType == typeof(List<TelemetryData>)) return typeof(F.TelemetryDataBatch);
            return domainType;
        }

        public static F.SimpleObject ToFlatSharp(SimpleObject obj) => obj == null ? null : new F.SimpleObject
        {
            Id = obj.Id, Name = obj.Name, Timestamp = obj.Timestamp.ToBinary(), IsActive = obj.IsActive
        };
        public static SimpleObject FromFlatSharp(F.SimpleObject obj) => obj == null ? null : new SimpleObject
        {
            Id = obj.Id, Name = obj.Name, Timestamp = DateTime.FromBinary(obj.Timestamp), IsActive = obj.IsActive
        };

        public static F.StringArrayObject ToFlatSharp(StringArrayObject obj) => obj == null ? null : new F.StringArrayObject
        {
            Items = obj.Items?.ToList()
        };
        public static StringArrayObject FromFlatSharp(F.StringArrayObject obj) => obj == null ? null : new StringArrayObject
        {
            Items = obj.Items?.ToList()
        };

        public static F.ServiceLine ToFlatSharp(ServiceLine l) => l == null ? null : new F.ServiceLine
        {
            ServiceCode = l.ServiceCode, ChargeAmount = l.ChargeAmount, AdjudicatedAmount = l.AdjudicatedAmount
        };
        public static ServiceLine FromFlatSharp(F.ServiceLine l) => l == null ? null : new ServiceLine
        {
            ServiceCode = l.ServiceCode, ChargeAmount = l.ChargeAmount, AdjudicatedAmount = l.AdjudicatedAmount
        };

        public static F.Claim ToFlatSharp(Claim c) => c == null ? null : new F.Claim
        {
            ClaimId = c.ClaimId, PatientName = c.PatientName, TotalCharge = c.TotalCharge, PaymentAmount = c.PaymentAmount,
            Lines = c.Lines?.Select(ToFlatSharp).ToList()
        };
        public static Claim FromFlatSharp(F.Claim c) => c == null ? null : new Claim
        {
            ClaimId = c.ClaimId, PatientName = c.PatientName, TotalCharge = c.TotalCharge, PaymentAmount = c.PaymentAmount,
            Lines = c.Lines?.Select(FromFlatSharp).ToList() ?? new List<ServiceLine>()
        };

        public static F.EDI835 ToFlatSharp(EDI835 d) => d == null ? null : new F.EDI835
        {
            PayerName = d.PayerName, PayeeName = d.PayeeName, PaymentDate = d.PaymentDate.ToBinary(),
            TotalActualAmount = d.TotalActualAmount, TransactionControlNumber = d.TransactionControlNumber,
            Claims = d.Claims?.Select(ToFlatSharp).ToList()
        };
        public static EDI835 FromFlatSharp(F.EDI835 d) => d == null ? null : new EDI835
        {
            PayerName = d.PayerName, PayeeName = d.PayeeName, PaymentDate = DateTime.FromBinary(d.PaymentDate),
            TotalActualAmount = d.TotalActualAmount, TransactionControlNumber = d.TransactionControlNumber,
            Claims = d.Claims?.Select(FromFlatSharp).ToList() ?? new List<Claim>()
        };

        public static F.TelemetryData ToFlatSharp(TelemetryData t) => t == null ? null : new F.TelemetryData
        {
            Id = t.Id, DataSource = t.DataSource, TimeStamp = t.TimeStamp.ToBinary(),
            Param1 = t.Param1, Param2 = t.Param2,
            Measurements = t.Measurements?.ToList(),
            AssociatedProblemID = t.AssociatedProblemID, AssociatedLogID = t.AssociatedLogID,
            WasProcessed = t.WasProcessed
        };
        public static TelemetryData FromFlatSharp(F.TelemetryData t) => t == null ? null : new TelemetryData
        {
            Id = t.Id, DataSource = t.DataSource, TimeStamp = DateTime.FromBinary(t.TimeStamp),
            Param1 = t.Param1, Param2 = t.Param2,
            Measurements = t.Measurements?.ToArray() ?? Array.Empty<double>(),
            AssociatedProblemID = t.AssociatedProblemID, AssociatedLogID = t.AssociatedLogID,
            WasProcessed = t.WasProcessed
        };
    }
}
