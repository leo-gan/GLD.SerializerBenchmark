using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using GLD.SerializerBenchmark.TestData.V2;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// CSV is tabular: timed path writes/reads a single-column envelope of domain JSON.
    /// (CsvHelper cannot express nested V2 graphs as columns without lossy projection.)
    /// </summary>
    internal class CsvHelperSerializerSer : SerDeser
    {
        private List<CsvRow> _rows;

        public override string Name => "CsvHelper";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data)
        {
            _rows = new List<CsvRow>
            {
                new CsvRow
                {
                    TypeName = data.GetType().AssemblyQualifiedName,
                    Payload = JsonConvert.SerializeObject(data)
                }
            };
        }

        public override object ToDomain(object decoded)
        {
            var rows = ((IEnumerable)decoded).Cast<CsvRow>().ToList();
            var r = rows[0];
            return JsonConvert.DeserializeObject(r.Payload, Type.GetType(r.TypeName));
        }

        public override string Serialize(object serializable)
        {
            var rows = _rows ?? Make(serializable);
            using var w = new StringWriter();
            using var csv = new CsvWriter(w, new CsvConfiguration(CultureInfo.InvariantCulture));
            csv.WriteRecords(rows);
            return w.ToString();
        }

        public override object Deserialize(string serialized)
        {
            using var r = new StringReader(serialized);
            using var csv = new CsvReader(r, new CsvConfiguration(CultureInfo.InvariantCulture));
            return csv.GetRecords<CsvRow>().ToList();
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using var w = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            using var csv = new CsvWriter(w, new CsvConfiguration(CultureInfo.InvariantCulture));
            csv.WriteRecords(_rows ?? Make(serializable));
            w.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var r = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            using var csv = new CsvReader(r, new CsvConfiguration(CultureInfo.InvariantCulture));
            return csv.GetRecords<CsvRow>().ToList();
        }

        static List<CsvRow> Make(object data) => new List<CsvRow>
        {
            new CsvRow { TypeName = data.GetType().AssemblyQualifiedName, Payload = JsonConvert.SerializeObject(data) }
        };

        public class CsvRow
        {
            public string TypeName { get; set; }
            public string Payload { get; set; }
        }
    }
}
