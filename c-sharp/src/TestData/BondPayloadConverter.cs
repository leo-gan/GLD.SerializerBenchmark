using System;
using System.Collections.Generic;
using System.Linq;
using B = GLD.SerializerBenchmark.Bond;

namespace GLD.SerializerBenchmark.TestData
{
    /// <summary>Map suite POCOs to Bond-generated schema types (and back) for MS Bond codecs.</summary>
    public static class BondPayloadConverter
    {
        public static object ToBond(object data)
        {
            if (data == null) return null;
            switch (data)
            {
                case SimpleObject s: return ToBond(s);
                case StringArrayObject a: return ToBond(a);
                case TelemetryData t: return ToBond(t);
                case EDI835 d: return ToBond(d);
                case List<SimpleObject> ls:
                    return new B.SimpleObjectBatch { Items = ls.Select(ToBond).ToList() };
                case List<StringArrayObject> la:
                    return new B.StringArrayObjectBatch { Items = la.Select(ToBond).ToList() };
                case List<TelemetryData> lt:
                    return new B.TelemetryDataBatch { Items = lt.Select(ToBond).ToList() };
                case List<EDI835> ld:
                    return new B.EDI835Batch { Items = ld.Select(ToBond).ToList() };
                default: return data;
            }
        }

        public static object FromBond(object data)
        {
            if (data == null) return null;
            switch (data)
            {
                case B.SimpleObject s: return FromBond(s);
                case B.StringArrayObject a: return FromBond(a);
                case B.TelemetryData t: return FromBond(t);
                case B.EDI835 d: return FromBond(d);
                case B.SimpleObjectBatch ls: return ls.Items.Select(FromBond).ToList();
                case B.StringArrayObjectBatch la: return la.Items.Select(FromBond).ToList();
                case B.TelemetryDataBatch lt: return lt.Items.Select(FromBond).ToList();
                case B.EDI835Batch ld: return ld.Items.Select(FromBond).ToList();
                default: return data;
            }
        }

        public static Type BondTypeFor(Type domainType)
        {
            if (domainType == typeof(SimpleObject)) return typeof(B.SimpleObject);
            if (domainType == typeof(StringArrayObject)) return typeof(B.StringArrayObject);
            if (domainType == typeof(TelemetryData)) return typeof(B.TelemetryData);
            if (domainType == typeof(EDI835)) return typeof(B.EDI835);
            if (domainType == typeof(List<SimpleObject>)) return typeof(B.SimpleObjectBatch);
            if (domainType == typeof(List<StringArrayObject>)) return typeof(B.StringArrayObjectBatch);
            if (domainType == typeof(List<TelemetryData>)) return typeof(B.TelemetryDataBatch);
            if (domainType == typeof(List<EDI835>)) return typeof(B.EDI835Batch);
            return domainType;
        }

        public static B.SimpleObject ToBond(SimpleObject o) => o == null ? null : new B.SimpleObject
        {
            Id = o.Id, Name = o.Name ?? "", Timestamp = o.Timestamp.ToBinary(), IsActive = o.IsActive
        };
        public static SimpleObject FromBond(B.SimpleObject o) => o == null ? null : new SimpleObject
        {
            Id = o.Id, Name = o.Name, Timestamp = DateTime.FromBinary(o.Timestamp), IsActive = o.IsActive
        };

        public static B.StringArrayObject ToBond(StringArrayObject o) => o == null ? null : new B.StringArrayObject
        {
            Items = o.Items == null ? new List<string>() : o.Items.ToList()
        };
        public static StringArrayObject FromBond(B.StringArrayObject o) => o == null ? null : new StringArrayObject
        {
            Items = o.Items == null ? new List<string>() : o.Items.ToList()
        };

        public static B.TelemetryData ToBond(TelemetryData o) => o == null ? null : new B.TelemetryData
        {
            Id = o.Id ?? "",
            DataSource = o.DataSource ?? "",
            TimeStamp = o.TimeStamp.ToBinary(),
            Param1 = o.Param1,
            Param2 = o.Param2,
            Measurements = o.Measurements == null ? new List<double>() : o.Measurements.ToList(),
            AssociatedProblemID = o.AssociatedProblemID,
            AssociatedLogID = o.AssociatedLogID,
            WasProcessed = o.WasProcessed
        };
        public static TelemetryData FromBond(B.TelemetryData o) => o == null ? null : new TelemetryData
        {
            Id = o.Id,
            DataSource = o.DataSource,
            TimeStamp = DateTime.FromBinary(o.TimeStamp),
            Param1 = o.Param1,
            Param2 = o.Param2,
            Measurements = o.Measurements == null ? Array.Empty<double>() : o.Measurements.ToArray(),
            AssociatedProblemID = o.AssociatedProblemID,
            AssociatedLogID = o.AssociatedLogID,
            WasProcessed = o.WasProcessed
        };

        public static B.EDI835 ToBond(EDI835 o)
        {
            if (o == null) return null;
            var b = new B.EDI835
            {
                PayerName = o.PayerName ?? "",
                PayeeName = o.PayeeName ?? "",
                PaymentDate = o.PaymentDate.ToBinary(),
                TotalActualAmount = o.TotalActualAmount,
                TransactionControlNumber = o.TransactionControlNumber ?? "",
                Claims = new List<B.Claim>()
            };
            if (o.Claims != null)
            {
                foreach (var c in o.Claims)
                {
                    var bc = new B.Claim
                    {
                        ClaimId = c.ClaimId ?? "",
                        PatientName = c.PatientName ?? "",
                        TotalCharge = c.TotalCharge,
                        PaymentAmount = c.PaymentAmount,
                        Lines = new List<B.ServiceLine>()
                    };
                    if (c.Lines != null)
                        foreach (var l in c.Lines)
                            bc.Lines.Add(new B.ServiceLine
                            {
                                ServiceCode = l.ServiceCode ?? "",
                                ChargeAmount = l.ChargeAmount,
                                AdjudicatedAmount = l.AdjudicatedAmount
                            });
                    b.Claims.Add(bc);
                }
            }
            return b;
        }

        public static EDI835 FromBond(B.EDI835 o)
        {
            if (o == null) return null;
            var d = new EDI835
            {
                PayerName = o.PayerName,
                PayeeName = o.PayeeName,
                PaymentDate = DateTime.FromBinary(o.PaymentDate),
                TotalActualAmount = o.TotalActualAmount,
                TransactionControlNumber = o.TransactionControlNumber,
                Claims = new List<Claim>()
            };
            if (o.Claims != null)
            {
                foreach (var c in o.Claims)
                {
                    var cl = new Claim
                    {
                        ClaimId = c.ClaimId,
                        PatientName = c.PatientName,
                        TotalCharge = c.TotalCharge,
                        PaymentAmount = c.PaymentAmount,
                        Lines = new List<ServiceLine>()
                    };
                    if (c.Lines != null)
                        foreach (var l in c.Lines)
                            cl.Lines.Add(new ServiceLine
                            {
                                ServiceCode = l.ServiceCode,
                                ChargeAmount = l.ChargeAmount,
                                AdjudicatedAmount = l.AdjudicatedAmount
                            });
                    d.Claims.Add(cl);
                }
            }
            return d;
        }
    }
}
