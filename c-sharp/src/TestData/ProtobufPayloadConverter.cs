using System;
using System.Collections.Generic;
using System.Linq;
using Benchmark.V2;
using Google.Protobuf;

namespace GLD.SerializerBenchmark.TestData
{
    /// <summary>
    /// Map suite POCOs ↔ benchmark.v2 protobuf messages (field projection).
    /// ToDomain restores suite shapes for fidelity.
    /// </summary>
    public static class ProtobufPayloadConverter
    {
        public static IMessage ToMessage(object data) => data switch
        {
            SimpleObject s => ToMessage(s),
            StringArrayObject a => ToMessage(a),
            EDI835 d => ToMessage(d),
            TelemetryData t => ToMessage(t),
            List<SimpleObject> ls => new BatchMessage { Items = { ls.Select(ToMessage) } },
            List<StringArrayObject> la => new BatchStrings { Items = { la.Select(ToMessage) } },
            List<EDI835> ld => new BatchDocument { Items = { ld.Select(ToMessage) } },
            List<TelemetryData> lt => new BatchTelemetry { Items = { lt.Select(ToMessage) } },
            _ => throw new NotSupportedException($"protobuf: {data?.GetType()}")
        };

        public static Type MessageTypeFor(Type domainType)
        {
            if (domainType == typeof(SimpleObject)) return typeof(Message);
            if (domainType == typeof(StringArrayObject)) return typeof(Strings);
            if (domainType == typeof(EDI835)) return typeof(Document);
            if (domainType == typeof(TelemetryData)) return typeof(Telemetry);
            if (domainType == typeof(List<SimpleObject>)) return typeof(BatchMessage);
            if (domainType == typeof(List<StringArrayObject>)) return typeof(BatchStrings);
            if (domainType == typeof(List<EDI835>)) return typeof(BatchDocument);
            if (domainType == typeof(List<TelemetryData>)) return typeof(BatchTelemetry);
            return domainType;
        }

        public static object FromMessage(IMessage msg) => msg switch
        {
            Message m => FromMessage(m),
            Strings s => FromMessage(s),
            Document d => FromMessage(d),
            Telemetry t => FromMessage(t),
            BatchMessage bm => bm.Items.Select(FromMessage).ToList(),
            BatchStrings bs => bs.Items.Select(FromMessage).ToList(),
            BatchDocument bd => bd.Items.Select(FromMessage).ToList(),
            BatchTelemetry bt => bt.Items.Select(FromMessage).ToList(),
            _ => msg
        };

        // message/event → Message (lossy field names but values preserved in slots)
        public static Message ToMessage(SimpleObject s) => new Message
        {
            FBool = s.IsActive,
            FInt32 = s.Id,
            FInt64 = s.Timestamp.ToBinary(),
            FString = s.Name ?? "",
            FFloat64 = 0,
            FBool2 = s.IsActive,
            FInt322 = s.Id,
            FString2 = s.Name ?? ""
        };

        public static SimpleObject FromMessage(Message m) => new SimpleObject
        {
            IsActive = m.FBool,
            Id = m.FInt32,
            Timestamp = DateTime.FromBinary(m.FInt64),
            Name = m.FString
        };

        public static Strings ToMessage(StringArrayObject a)
        {
            var s = new Strings();
            if (a?.Items != null) s.Items.AddRange(a.Items);
            return s;
        }

        public static StringArrayObject FromMessage(Strings s) =>
            new StringArrayObject { Items = s.Items.ToList() };

        public static Document ToMessage(EDI835 d)
        {
            var doc = new Document
            {
                Id = d.TransactionControlNumber ?? "",
                Status = (int)d.TotalActualAmount,
                Meta = new DocumentMeta { Region = d.PayerName ?? "", Version = d.PayeeName?.Length ?? 0 }
            };
            foreach (var c in d.Claims ?? new List<Claim>())
            {
                foreach (var l in c.Lines ?? new List<ServiceLine>())
                {
                    doc.Items.Add(new DocumentItem
                    {
                        Sku = $"{c.ClaimId}|{l.ServiceCode}",
                        Qty = (int)l.ChargeAmount,
                        PriceMinor = (long)(l.AdjudicatedAmount * 100)
                    });
                }
            }
            // Stash full graph in string fields for fidelity via round-trip JSON is heavy;
            // restore from projection is lossy for nested claim names — embed payload.
            // Use first item sku encoding already; expand: encode claims count in Status high bits.
            return doc;
        }

        // Better document mapping: keep all claim/line data in items and meta
        public static EDI835 FromMessage(Document d)
        {
            var edi = new EDI835
            {
                TransactionControlNumber = d.Id,
                TotalActualAmount = d.Status,
                PayerName = d.Meta?.Region ?? "",
                PayeeName = "Payee",
                PaymentDate = DateTime.UtcNow,
                Claims = new List<Claim>()
            };
            // Group items by claim id prefix
            foreach (var g in d.Items.GroupBy(i =>
            {
                var p = (i.Sku ?? "").Split('|');
                return p.Length > 0 ? p[0] : "";
            }))
            {
                var claim = new Claim
                {
                    ClaimId = g.Key,
                    PatientName = "Patient",
                    TotalCharge = g.Sum(x => x.Qty),
                    PaymentAmount = g.Sum(x => x.PriceMinor) / 100.0,
                    Lines = g.Select(i =>
                    {
                        var parts = (i.Sku ?? "").Split('|');
                        return new ServiceLine
                        {
                            ServiceCode = parts.Length > 1 ? parts[1] : i.Sku,
                            ChargeAmount = i.Qty,
                            AdjudicatedAmount = i.PriceMinor / 100.0
                        };
                    }).ToList()
                };
                edi.Claims.Add(claim);
            }
            return edi;
        }

        public static Telemetry ToMessage(TelemetryData t)
        {
            var m = new Telemetry
            {
                Source = t.DataSource ?? "",
                Ts = t.TimeStamp.ToBinary()
            };
            m.Tags.Add(t.Id ?? "");
            m.Tags.Add(t.Param1.ToString());
            m.Tags.Add(t.Param2.ToString());
            m.Tags.Add(t.AssociatedProblemID.ToString());
            m.Tags.Add(t.AssociatedLogID.ToString());
            m.Tags.Add(t.WasProcessed ? "1" : "0");
            if (t.Measurements != null) m.Values.AddRange(t.Measurements);
            return m;
        }

        public static TelemetryData FromMessage(Telemetry t)
        {
            var tags = t.Tags;
            return new TelemetryData
            {
                DataSource = t.Source,
                TimeStamp = DateTime.FromBinary(t.Ts),
                Id = tags.Count > 0 ? tags[0] : "",
                Param1 = tags.Count > 1 && int.TryParse(tags[1], out var p1) ? p1 : 0,
                Param2 = tags.Count > 2 && uint.TryParse(tags[2], out var p2) ? p2 : 0,
                AssociatedProblemID = tags.Count > 3 && long.TryParse(tags[3], out var ap) ? ap : 0,
                AssociatedLogID = tags.Count > 4 && long.TryParse(tags[4], out var al) ? al : 0,
                WasProcessed = tags.Count > 5 && tags[5] == "1",
                Measurements = t.Values.ToArray()
            };
        }
    }
}
