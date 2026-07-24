using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// CsvHelper on row-list contracts only (CsvFlatRow / CsvEventRow / CsvStringRow).
    /// Domain projection via <see cref="IDomainNativeMap"/> (untimed). Supports message/event/strings.
    /// <para>
    /// Timed path uses real CsvHelper <c>WriteRecords</c> / <c>GetRecords</c> (not a JSON envelope).
    /// Stream mode is <b>adapted</b>: UTF-8 StreamWriter/Reader around the same CSV text path.
    /// </para>
    /// https://joshclose.github.io/CsvHelper/
    /// </summary>
    internal class CsvHelperSerializerSer : MappedSerDeser
    {
        private static readonly CsvConfiguration Cfg = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = true,
            NewLine = "\n",
        };

        private Type _rowElementType;

        public CsvHelperSerializerSer(IDomainNativeMap map) : base(map) { }

        public override string Name => "CsvHelper";

        public override bool Supports(string testDataName)
            => testDataName is "message" or "event" or "strings";

        protected override void OnNativeTypeReady(Type nativeRoot, List<Type> nativeSecondary)
        {
            // nativeRoot is List<TRow>
            if (nativeRoot.IsGenericType && nativeRoot.GetGenericTypeDefinition() == typeof(List<>))
                _rowElementType = nativeRoot.GetGenericArguments()[0];
            else
                throw new InvalidOperationException($"CsvHelper expects List<TRow>, got {nativeRoot}");
        }

        public override string Serialize(object serializable)
        {
            var rows = NativeOf(serializable);
            using var w = new StringWriter();
            using var csv = new CsvWriter(w, Cfg);
            WriteRecords(csv, rows);
            return w.ToString();
        }

        public override object Deserialize(string serialized)
        {
            using var r = new StringReader(serialized);
            using var csv = new CsvReader(r, Cfg);
            return ReadRecords(csv);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using var w = new StreamWriter(outputStream, new UTF8Encoding(false), 1024, leaveOpen: true);
            using var csv = new CsvWriter(w, Cfg);
            WriteRecords(csv, NativeOf(serializable));
            w.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var r = new StreamReader(inputStream, Encoding.UTF8, false, 1024, leaveOpen: true);
            using var csv = new CsvReader(r, Cfg);
            return ReadRecords(csv);
        }

        void WriteRecords(CsvWriter csv, object rows)
        {
            // CsvWriter.WriteRecords(IEnumerable) non-generic
            csv.WriteRecords((IEnumerable)rows);
        }

        object ReadRecords(CsvReader csv)
        {
            // GetRecords<T>() via reflection
            var mi = typeof(CsvReader).GetMethods()
                .First(m => m.Name == "GetRecords" && m.IsGenericMethodDefinition
                            && m.GetParameters().Length == 0);
            var closed = mi.MakeGenericMethod(_rowElementType);
            var enumerable = closed.Invoke(csv, null);
            // Materialize to List<TRow>
            var listType = typeof(List<>).MakeGenericType(_rowElementType);
            var list = (IList)Activator.CreateInstance(listType);
            foreach (var item in (IEnumerable)enumerable)
                list.Add(item);
            return list;
        }
    }
}
