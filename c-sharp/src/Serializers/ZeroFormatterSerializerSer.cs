using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using GLD.SerializerBenchmark.TestData;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// ZeroFormatter on modern .NET cannot emit dynamic formatters for
    /// <c>[ZeroFormattable]</c> classes (BadImageFormatException). Built-in
    /// formatters still work: primitives, arrays, lists, and <see cref="KeyTuple"/>.
    ///
    /// All suite fixtures map to KeyTuple / List&lt;KeyTuple&gt; shapes in
    /// <see cref="PrepareData"/> (untimed); timed path is pure Serialize/Deserialize.
    /// </summary>
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        private object _native; // KeyTuple / list / int prepared form

        public override string Name => "ZeroFormatter";

        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data)
        {
            _native = ToNative(data);
        }

        public override string Serialize(object serializable) =>
            Convert.ToBase64String(SerializeBytes(Native(serializable)));

        // Timed path returns KeyTuple / list native shapes; ToDomain is untimed.
        public override object Deserialize(string serialized) =>
            DeserializeBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = SerializeBytes(Native(serializable));
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return DeserializeBytes(ms.ToArray());
        }

        public override object ToDomain(object decoded) => FromNative(decoded);

        private object Native(object serializable) =>
            _native ?? ToNative(serializable);

        private byte[] SerializeBytes(object native)
        {
            if (native == null)
                throw new ArgumentNullException(nameof(native));

            // Dispatch by prepared native shape (KeyTuple / List / int).
            switch (native)
            {
                case int i:
                    return ZeroFormatterSerializer.Serialize(i);
                case KeyTuple<int, string, DateTime, bool> simple:
                    return ZeroFormatterSerializer.Serialize(simple);
                case List<string> strings:
                    return ZeroFormatterSerializer.Serialize(strings);
                case KeyTuple<int, List<KeyTuple<string, int, int, List<int>>>> graph:
                    return ZeroFormatterSerializer.Serialize(graph);
                case KeyTuple<string, string, uint, int, KeyTuple<string, string, DateTime>, List<KeyTuple<int, string>>> person:
                    return ZeroFormatterSerializer.Serialize(person);
                // Telemetry nested: KeyTuple max arity is 8.
                case KeyTuple<KeyTuple<string, string, DateTime, int, uint>, KeyTuple<List<double>, long, long, bool>> telemetry:
                    return ZeroFormatterSerializer.Serialize(telemetry);
                case KeyTuple<string, string, DateTime, double, string, List<KeyTuple<string, string, double, double, List<KeyTuple<string, double, double>>>>> edi:
                    return ZeroFormatterSerializer.Serialize(edi);
                default:
                    throw new NotSupportedException(
                        $"ZeroFormatter native shape not registered: {native.GetType().FullName}");
            }
        }

        private object DeserializeBytes(byte[] bytes)
        {
            if (_primaryType == typeof(int))
                return ZeroFormatterSerializer.Deserialize<int>(bytes);

            if (_primaryType == typeof(SimpleObject))
                return ZeroFormatterSerializer.Deserialize<KeyTuple<int, string, DateTime, bool>>(bytes);

            if (_primaryType == typeof(StringArrayObject))
                return ZeroFormatterSerializer.Deserialize<List<string>>(bytes);

            if (_primaryType == typeof(ObjectGraph))
                return ZeroFormatterSerializer
                    .Deserialize<KeyTuple<int, List<KeyTuple<string, int, int, List<int>>>>>(bytes);

            if (_primaryType == typeof(Person))
                return ZeroFormatterSerializer
                    .Deserialize<KeyTuple<string, string, uint, int, KeyTuple<string, string, DateTime>, List<KeyTuple<int, string>>>>(bytes);

            if (_primaryType == typeof(TelemetryData))
                return ZeroFormatterSerializer
                    .Deserialize<KeyTuple<KeyTuple<string, string, DateTime, int, uint>, KeyTuple<List<double>, long, long, bool>>>(bytes);

            if (_primaryType == typeof(EDI835))
                return ZeroFormatterSerializer
                    .Deserialize<KeyTuple<string, string, DateTime, double, string, List<KeyTuple<string, string, double, double, List<KeyTuple<string, double, double>>>>>>(bytes);

            throw new NotSupportedException(
                $"ZeroFormatter does not support primary type {_primaryType?.FullName ?? "(null)"}.");
        }

        private object ToNative(object data)
        {
            if (data is int i)
                return i;

            if (data is SimpleObject o)
                return KeyTuple.Create(o.Id, o.Name ?? "", o.Timestamp, o.IsActive);

            if (data is StringArrayObject sa)
                return sa.Items != null ? sa.Items.ToList() : new List<string>();

            if (data is ObjectGraph g)
            {
                var nodes = (g.Nodes ?? new List<GraphNodeData>())
                    .Select(n => KeyTuple.Create(
                        n.Name ?? "",
                        n.Parent,
                        n.Related,
                        n.Children != null ? n.Children.ToList() : new List<int>()))
                    .ToList();
                return KeyTuple.Create(g.Root, nodes);
            }

            if (data is Person p)
            {
                var pass = p.Passport ?? new Passport();
                var records = (p.PoliceRecords ?? Array.Empty<PoliceRecord>())
                    .Select(r => KeyTuple.Create(r.Id, r.CrimeCode ?? ""))
                    .ToList();
                return KeyTuple.Create(
                    p.FirstName ?? "",
                    p.LastName ?? "",
                    p.Age,
                    (int)p.Gender,
                    KeyTuple.Create(pass.Number ?? "", pass.Authority ?? "", pass.ExpirationDate),
                    records);
            }

            if (data is TelemetryData t)
            {
                var meas = t.Measurements != null
                    ? t.Measurements.ToList()
                    : new List<double>();
                // Nest because KeyTuple.Create supports at most 8 type args.
                return KeyTuple.Create(
                    KeyTuple.Create(
                        t.Id ?? "",
                        t.DataSource ?? "",
                        t.TimeStamp,
                        t.Param1,
                        t.Param2),
                    KeyTuple.Create(
                        meas,
                        t.AssociatedProblemID,
                        t.AssociatedLogID,
                        t.WasProcessed));
            }

            if (data is EDI835 e)
            {
                var claims = (e.Claims ?? new List<Claim>())
                    .Select(c => KeyTuple.Create(
                        c.ClaimId ?? "",
                        c.PatientName ?? "",
                        c.TotalCharge,
                        c.PaymentAmount,
                        (c.Lines ?? new List<ServiceLine>())
                            .Select(l => KeyTuple.Create(
                                l.ServiceCode ?? "",
                                l.ChargeAmount,
                                l.AdjudicatedAmount))
                            .ToList()))
                    .ToList();
                return KeyTuple.Create(
                    e.PayerName ?? "",
                    e.PayeeName ?? "",
                    e.PaymentDate,
                    e.TotalActualAmount,
                    e.TransactionControlNumber ?? "",
                    claims);
            }

            throw new NotSupportedException(
                $"ZeroFormatter ToNative unsupported: {data?.GetType().FullName ?? "null"}");
        }

        private object FromNative(object native)
        {
            if (_primaryType == typeof(int))
                return native;

            if (_primaryType == typeof(SimpleObject))
            {
                var t = (KeyTuple<int, string, DateTime, bool>)native;
                return new SimpleObject
                {
                    Id = t.Item1,
                    Name = t.Item2,
                    Timestamp = t.Item3,
                    IsActive = t.Item4
                };
            }

            if (_primaryType == typeof(StringArrayObject))
                return new StringArrayObject { Items = (List<string>)native };

            if (_primaryType == typeof(ObjectGraph))
            {
                var t = (KeyTuple<int, List<KeyTuple<string, int, int, List<int>>>>)native;
                return new ObjectGraph
                {
                    Root = t.Item1,
                    Nodes = (t.Item2 ?? new List<KeyTuple<string, int, int, List<int>>>())
                        .Select(n => new GraphNodeData
                        {
                            Name = n.Item1,
                            Parent = n.Item2,
                            Related = n.Item3,
                            Children = n.Item4 ?? new List<int>()
                        }).ToList()
                };
            }

            if (_primaryType == typeof(Person))
            {
                var t = (KeyTuple<string, string, uint, int, KeyTuple<string, string, DateTime>, List<KeyTuple<int, string>>>)native;
                var pass = t.Item5;
                return new Person
                {
                    FirstName = t.Item1,
                    LastName = t.Item2,
                    Age = t.Item3,
                    Gender = (Gender)t.Item4,
                    Passport = new Passport
                    {
                        Number = pass.Item1,
                        Authority = pass.Item2,
                        ExpirationDate = pass.Item3
                    },
                    PoliceRecords = (t.Item6 ?? new List<KeyTuple<int, string>>())
                        .Select(r => new PoliceRecord { Id = r.Item1, CrimeCode = r.Item2 })
                        .ToArray()
                };
            }

            if (_primaryType == typeof(TelemetryData))
            {
                var t = (KeyTuple<KeyTuple<string, string, DateTime, int, uint>, KeyTuple<List<double>, long, long, bool>>)native;
                var a = t.Item1;
                var b = t.Item2;
                return new TelemetryData
                {
                    Id = a.Item1,
                    DataSource = a.Item2,
                    TimeStamp = a.Item3,
                    Param1 = a.Item4,
                    Param2 = a.Item5,
                    Measurements = b.Item1?.ToArray() ?? Array.Empty<double>(),
                    AssociatedProblemID = b.Item2,
                    AssociatedLogID = b.Item3,
                    WasProcessed = b.Item4
                };
            }

            if (_primaryType == typeof(EDI835))
            {
                var t = (KeyTuple<string, string, DateTime, double, string, List<KeyTuple<string, string, double, double, List<KeyTuple<string, double, double>>>>>)native;
                return new EDI835
                {
                    PayerName = t.Item1,
                    PayeeName = t.Item2,
                    PaymentDate = t.Item3,
                    TotalActualAmount = t.Item4,
                    TransactionControlNumber = t.Item5,
                    Claims = (t.Item6 ?? new List<KeyTuple<string, string, double, double, List<KeyTuple<string, double, double>>>>())
                        .Select(c => new Claim
                        {
                            ClaimId = c.Item1,
                            PatientName = c.Item2,
                            TotalCharge = c.Item3,
                            PaymentAmount = c.Item4,
                            Lines = (c.Item5 ?? new List<KeyTuple<string, double, double>>())
                                .Select(l => new ServiceLine
                                {
                                    ServiceCode = l.Item1,
                                    ChargeAmount = l.Item2,
                                    AdjudicatedAmount = l.Item3
                                }).ToList()
                        }).ToList()
                };
            }

            return native;
        }
    }
}
