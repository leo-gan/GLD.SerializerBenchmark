using System;
using System.Collections.Generic;
using System.Linq;
using M = GLD.SerializerBenchmark.MPack;

namespace GLD.SerializerBenchmark.TestData
{
    public static class MemoryPackTypeConverter
    {
        public static object ToNative(object data)
        {
            if (data == null) return null;
            return data switch
            {
                SimpleObject s => ToMemoryPack(s),
                StringArrayObject a => ToMemoryPack(a),
                EDI835 d => ToMemoryPack(d),
                TelemetryData t => ToMemoryPack(t),
                List<SimpleObject> ls => new M.SimpleObjectBatch { Items = ls.Select(ToMemoryPack).ToList() },
                List<StringArrayObject> la => new M.StringArrayObjectBatch { Items = la.Select(ToMemoryPack).ToList() },
                List<EDI835> ld => new M.EDI835Batch { Items = ld.Select(ToMemoryPack).ToList() },
                List<TelemetryData> lt => new M.TelemetryDataBatch { Items = lt.Select(ToMemoryPack).ToList() },
                _ => data
            };
        }

        public static object FromNative(object data)
        {
            if (data == null) return null;
            return data switch
            {
                M.SimpleObject s => FromMemoryPack(s),
                M.StringArrayObject a => FromMemoryPack(a),
                M.EDI835 d => FromMemoryPack(d),
                M.TelemetryData t => FromMemoryPack(t),
                M.SimpleObjectBatch ls => ls.Items.Select(FromMemoryPack).ToList(),
                M.StringArrayObjectBatch la => la.Items.Select(FromMemoryPack).ToList(),
                M.EDI835Batch ld => ld.Items.Select(FromMemoryPack).ToList(),
                M.TelemetryDataBatch lt => lt.Items.Select(FromMemoryPack).ToList(),
                _ => data
            };
        }

        public static Type NativeTypeFor(Type domainType)
        {
            if (domainType == typeof(SimpleObject)) return typeof(M.SimpleObject);
            if (domainType == typeof(StringArrayObject)) return typeof(M.StringArrayObject);
            if (domainType == typeof(EDI835)) return typeof(M.EDI835);
            if (domainType == typeof(TelemetryData)) return typeof(M.TelemetryData);
            if (domainType == typeof(List<SimpleObject>)) return typeof(M.SimpleObjectBatch);
            if (domainType == typeof(List<StringArrayObject>)) return typeof(M.StringArrayObjectBatch);
            if (domainType == typeof(List<EDI835>)) return typeof(M.EDI835Batch);
            if (domainType == typeof(List<TelemetryData>)) return typeof(M.TelemetryDataBatch);
            return domainType;
        }

        public static M.SimpleObject ToMemoryPack(SimpleObject obj) => obj == null ? null : new M.SimpleObject
        {
            Id = obj.Id, Name = obj.Name, Timestamp = obj.Timestamp, IsActive = obj.IsActive
        };
        public static SimpleObject FromMemoryPack(M.SimpleObject obj) => obj == null ? null : new SimpleObject
        {
            Id = obj.Id, Name = obj.Name, Timestamp = obj.Timestamp, IsActive = obj.IsActive
        };

        public static M.StringArrayObject ToMemoryPack(StringArrayObject obj) => obj == null ? null : new M.StringArrayObject
        {
            Items = obj.Items?.ToList()
        };
        public static StringArrayObject FromMemoryPack(M.StringArrayObject obj) => obj == null ? null : new StringArrayObject
        {
            Items = obj.Items?.ToList()
        };

        public static M.ServiceLine ToMemoryPack(ServiceLine l) => l == null ? null : new M.ServiceLine
        {
            ServiceCode = l.ServiceCode, ChargeAmount = l.ChargeAmount, AdjudicatedAmount = l.AdjudicatedAmount
        };
        public static ServiceLine FromMemoryPack(M.ServiceLine l) => l == null ? null : new ServiceLine
        {
            ServiceCode = l.ServiceCode, ChargeAmount = l.ChargeAmount, AdjudicatedAmount = l.AdjudicatedAmount
        };

        public static M.Claim ToMemoryPack(Claim c) => c == null ? null : new M.Claim
        {
            ClaimId = c.ClaimId, PatientName = c.PatientName, TotalCharge = c.TotalCharge, PaymentAmount = c.PaymentAmount,
            Lines = c.Lines?.Select(ToMemoryPack).ToList()
        };
        public static Claim FromMemoryPack(M.Claim c) => c == null ? null : new Claim
        {
            ClaimId = c.ClaimId, PatientName = c.PatientName, TotalCharge = c.TotalCharge, PaymentAmount = c.PaymentAmount,
            Lines = c.Lines?.Select(FromMemoryPack).ToList() ?? new List<ServiceLine>()
        };

        public static M.EDI835 ToMemoryPack(EDI835 d) => d == null ? null : new M.EDI835
        {
            PayerName = d.PayerName, PayeeName = d.PayeeName, PaymentDate = d.PaymentDate,
            TotalActualAmount = d.TotalActualAmount, TransactionControlNumber = d.TransactionControlNumber,
            Claims = d.Claims?.Select(ToMemoryPack).ToList()
        };
        public static EDI835 FromMemoryPack(M.EDI835 d) => d == null ? null : new EDI835
        {
            PayerName = d.PayerName, PayeeName = d.PayeeName, PaymentDate = d.PaymentDate,
            TotalActualAmount = d.TotalActualAmount, TransactionControlNumber = d.TransactionControlNumber,
            Claims = d.Claims?.Select(FromMemoryPack).ToList() ?? new List<Claim>()
        };

        public static M.TelemetryData ToMemoryPack(TelemetryData t) => t == null ? null : new M.TelemetryData
        {
            AssociatedLogID = t.AssociatedLogID, AssociatedProblemID = t.AssociatedProblemID,
            DataSource = t.DataSource, Id = t.Id,
            Measurements = t.Measurements?.ToList(),
            Param1 = t.Param1, Param2 = t.Param2, TimeStamp = t.TimeStamp, WasProcessed = t.WasProcessed
        };
        public static TelemetryData FromMemoryPack(M.TelemetryData t) => t == null ? null : new TelemetryData
        {
            AssociatedLogID = t.AssociatedLogID, AssociatedProblemID = t.AssociatedProblemID,
            DataSource = t.DataSource, Id = t.Id,
            Measurements = t.Measurements?.ToArray() ?? Array.Empty<double>(),
            Param1 = t.Param1, Param2 = t.Param2, TimeStamp = t.TimeStamp, WasProcessed = t.WasProcessed
        };
    }
}
