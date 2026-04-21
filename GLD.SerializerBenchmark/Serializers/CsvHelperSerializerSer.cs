using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // CsvHelper
    internal class CsvHelperSerializerSer : SerDeser
    {
        public override string Name => "CsvHelper";
        public override string Serialize(object serializable) {
            // CsvHelper doesn't natively serialize "object" generically easily, it requires enumerable.
            return ""; 
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
