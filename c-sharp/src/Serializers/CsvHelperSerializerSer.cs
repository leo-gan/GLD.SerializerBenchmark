using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// CsvHelper is tabular. Nested suite types are projected to flat DTO rows untimed (PrepareData);
    /// timed path is CsvWriter/CsvReader only. Round-trip restores domain via ToDomain.
    /// </summary>
    internal class CsvHelperSerializerSer : SerDeser
    {
        private object _rows; // IList of flat DTOs
        private Type _rowType;
        private string _shape; // simple|strings|document|telemetry|batch-simple|...

        public override string Name => "CsvHelper";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data)
        {
            (_rows, _rowType, _shape) = Project(data);
        }

        public override object ToDomain(object decoded) => Unproject(decoded, _shape);

        public override string Serialize(object serializable)
        {
            var (rows, rowType, _) = _rows != null ? (_rows, _rowType, _shape) : Project(serializable);
            using var writer = new StringWriter();
            using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture));
            WriteAll(csv, rows, rowType);
            return writer.ToString();
        }

        public override object Deserialize(string serialized)
        {
            using var reader = new StringReader(serialized);
            using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture));
            return ReadAll(csv, _rowType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var (rows, rowType, _) = _rows != null ? (_rows, _rowType, _shape) : Project(serializable);
            using var writer = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture));
            WriteAll(csv, rows, rowType);
            writer.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var reader = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture));
            return ReadAll(csv, _rowType);
        }

        static void WriteAll(CsvWriter csv, object rows, Type rowType)
        {
            var method = typeof(CsvWriter).GetMethods()
                .First(m => m.Name == "WriteRecords" && m.IsGenericMethod && m.GetParameters().Length == 1);
            method.MakeGenericMethod(rowType).Invoke(csv, new[] { rows });
        }

        static object ReadAll(CsvReader csv, Type rowType)
        {
            var method = typeof(CsvReader).GetMethods()
                .First(m => m.Name == "GetRecords" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 0);
            var enumerable = method.MakeGenericMethod(rowType).Invoke(csv, null) as IEnumerable;
            var listType = typeof(List<>).MakeGenericType(rowType);
            var list = (IList)Activator.CreateInstance(listType);
            foreach (var r in enumerable) list.Add(r);
            return list;
        }

        static (object rows, Type rowType, string shape) Project(object data)
        {
            switch (data)
            {
                case SimpleObject s:
                    return (new List<SimpleRow> { SimpleRow.From(s) }, typeof(SimpleRow), "simple");
                case List<SimpleObject> ls:
                    return (ls.Select(SimpleRow.From).ToList(), typeof(SimpleRow), "batch-simple");
                case StringArrayObject a:
                    return (a.Items.Select(x => new StringRow { Item = x }).ToList(), typeof(StringRow), "strings");
                case List<StringArrayObject> la:
                    // Flatten with group index
                    var rows = new List<StringBatchRow>();
                    for (int i = 0; i < la.Count; i++)
                        foreach (var s in la[i].Items ?? Enumerable.Empty<string>())
                            rows.Add(new StringBatchRow { Group = i, Item = s });
                    return (rows, typeof(StringBatchRow), "batch-strings");
                case EDI835 d:
                    return (DocRows.From(d), typeof(DocRow), "document");
                case List<EDI835> ld:
                    var dr = new List<DocRow>();
                    for (int i = 0; i < ld.Count; i++)
                        dr.AddRange(DocRows.From(ld[i], i));
                    return (dr, typeof(DocRow), "batch-document");
                case TelemetryData t:
                    return (TelRows.From(t), typeof(TelRow), "telemetry");
                case List<TelemetryData> lt:
                    var tr = new List<TelRow>();
                    for (int i = 0; i < lt.Count; i++)
                        tr.AddRange(TelRows.From(lt[i], i));
                    return (tr, typeof(TelRow), "batch-telemetry");
                default:
                    throw new NotSupportedException($"CsvHelper: {data?.GetType()}");
            }
        }

        static object Unproject(object decoded, string shape)
        {
            var list = ((IEnumerable)decoded).Cast<object>().ToList();
            switch (shape)
            {
                case "simple":
                    return ((SimpleRow)list[0]).ToDomain();
                case "batch-simple":
                    return list.Cast<SimpleRow>().Select(r => r.ToDomain()).ToList();
                case "strings":
                    return new StringArrayObject { Items = list.Cast<StringRow>().Select(r => r.Item).ToList() };
                case "batch-strings":
                    return list.Cast<StringBatchRow>().GroupBy(r => r.Group)
                        .OrderBy(g => g.Key)
                        .Select(g => new StringArrayObject { Items = g.Select(x => x.Item).ToList() })
                        .ToList();
                case "document":
                    return DocRows.ToDomain(list.Cast<DocRow>().ToList());
                case "batch-document":
                    return list.Cast<DocRow>().GroupBy(r => r.DocIndex).OrderBy(g => g.Key)
                        .Select(g => DocRows.ToDomain(g.ToList())).ToList();
                case "telemetry":
                    return TelRows.ToDomain(list.Cast<TelRow>().ToList());
                case "batch-telemetry":
                    return list.Cast<TelRow>().GroupBy(r => r.TelIndex).OrderBy(g => g.Key)
                        .Select(g => TelRows.ToDomain(g.ToList())).ToList();
                default:
                    return decoded;
            }
        }

        public class SimpleRow
        {
            public int Id { get; set; }
            public string Name { get; set; }
            public long Timestamp { get; set; }
            public bool IsActive { get; set; }
            public static SimpleRow From(SimpleObject s) => new SimpleRow
            {
                Id = s.Id, Name = s.Name, Timestamp = s.Timestamp.ToBinary(), IsActive = s.IsActive
            };
            public SimpleObject ToDomain() => new SimpleObject
            {
                Id = Id, Name = Name, Timestamp = DateTime.FromBinary(Timestamp), IsActive = IsActive
            };
        }

        public class StringRow { public string Item { get; set; } }
        public class StringBatchRow { public int Group { get; set; } public string Item { get; set; } }

        public class DocRow
        {
            public int DocIndex { get; set; }
            public string PayerName { get; set; }
            public string PayeeName { get; set; }
            public long PaymentDate { get; set; }
            public double TotalActualAmount { get; set; }
            public string TransactionControlNumber { get; set; }
            public string ClaimId { get; set; }
            public string PatientName { get; set; }
            public double TotalCharge { get; set; }
            public double PaymentAmount { get; set; }
            public string ServiceCode { get; set; }
            public double ChargeAmount { get; set; }
            public double AdjudicatedAmount { get; set; }
        }

        static class DocRows
        {
            public static List<DocRow> From(EDI835 d, int docIndex = 0)
            {
                var rows = new List<DocRow>();
                foreach (var c in d.Claims ?? new List<Claim>())
                {
                    foreach (var l in c.Lines ?? new List<ServiceLine>())
                    {
                        rows.Add(new DocRow
                        {
                            DocIndex = docIndex,
                            PayerName = d.PayerName,
                            PayeeName = d.PayeeName,
                            PaymentDate = d.PaymentDate.ToBinary(),
                            TotalActualAmount = d.TotalActualAmount,
                            TransactionControlNumber = d.TransactionControlNumber,
                            ClaimId = c.ClaimId,
                            PatientName = c.PatientName,
                            TotalCharge = c.TotalCharge,
                            PaymentAmount = c.PaymentAmount,
                            ServiceCode = l.ServiceCode,
                            ChargeAmount = l.ChargeAmount,
                            AdjudicatedAmount = l.AdjudicatedAmount
                        });
                    }
                }
                if (rows.Count == 0)
                {
                    rows.Add(new DocRow
                    {
                        DocIndex = docIndex,
                        PayerName = d.PayerName,
                        PayeeName = d.PayeeName,
                        PaymentDate = d.PaymentDate.ToBinary(),
                        TotalActualAmount = d.TotalActualAmount,
                        TransactionControlNumber = d.TransactionControlNumber
                    });
                }
                return rows;
            }

            public static EDI835 ToDomain(List<DocRow> rows)
            {
                var first = rows[0];
                var doc = new EDI835
                {
                    PayerName = first.PayerName,
                    PayeeName = first.PayeeName,
                    PaymentDate = DateTime.FromBinary(first.PaymentDate),
                    TotalActualAmount = first.TotalActualAmount,
                    TransactionControlNumber = first.TransactionControlNumber,
                    Claims = new List<Claim>()
                };
                foreach (var cg in rows.GroupBy(r => r.ClaimId))
                {
                    var c0 = cg.First();
                    if (string.IsNullOrEmpty(c0.ClaimId) && string.IsNullOrEmpty(c0.ServiceCode))
                        continue;
                    var claim = new Claim
                    {
                        ClaimId = c0.ClaimId,
                        PatientName = c0.PatientName,
                        TotalCharge = c0.TotalCharge,
                        PaymentAmount = c0.PaymentAmount,
                        Lines = cg.Where(x => !string.IsNullOrEmpty(x.ServiceCode)).Select(x => new ServiceLine
                        {
                            ServiceCode = x.ServiceCode,
                            ChargeAmount = x.ChargeAmount,
                            AdjudicatedAmount = x.AdjudicatedAmount
                        }).ToList()
                    };
                    doc.Claims.Add(claim);
                }
                return doc;
            }
        }

        public class TelRow
        {
            public int TelIndex { get; set; }
            public string Id { get; set; }
            public string DataSource { get; set; }
            public long TimeStamp { get; set; }
            public int Param1 { get; set; }
            public uint Param2 { get; set; }
            public long AssociatedProblemID { get; set; }
            public long AssociatedLogID { get; set; }
            public bool WasProcessed { get; set; }
            public int MeasIndex { get; set; }
            public double Measurement { get; set; }
        }

        static class TelRows
        {
            public static List<TelRow> From(TelemetryData t, int telIndex = 0)
            {
                var rows = new List<TelRow>();
                var meas = t.Measurements ?? Array.Empty<double>();
                if (meas.Length == 0)
                {
                    rows.Add(Base(t, telIndex, 0, 0));
                    return rows;
                }
                for (int i = 0; i < meas.Length; i++)
                    rows.Add(Base(t, telIndex, i, meas[i]));
                return rows;
            }

            static TelRow Base(TelemetryData t, int telIndex, int mi, double mv) => new TelRow
            {
                TelIndex = telIndex,
                Id = t.Id,
                DataSource = t.DataSource,
                TimeStamp = t.TimeStamp.ToBinary(),
                Param1 = t.Param1,
                Param2 = t.Param2,
                AssociatedProblemID = t.AssociatedProblemID,
                AssociatedLogID = t.AssociatedLogID,
                WasProcessed = t.WasProcessed,
                MeasIndex = mi,
                Measurement = mv
            };

            public static TelemetryData ToDomain(List<TelRow> rows)
            {
                var f = rows[0];
                var ordered = rows.OrderBy(r => r.MeasIndex).ToList();
                return new TelemetryData
                {
                    Id = f.Id,
                    DataSource = f.DataSource,
                    TimeStamp = DateTime.FromBinary(f.TimeStamp),
                    Param1 = f.Param1,
                    Param2 = f.Param2,
                    AssociatedProblemID = f.AssociatedProblemID,
                    AssociatedLogID = f.AssociatedLogID,
                    WasProcessed = f.WasProcessed,
                    Measurements = ordered.Select(r => r.Measurement).ToArray()
                };
            }
        }
    }
}
