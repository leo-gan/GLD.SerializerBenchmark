using System;
using System.IO;
using Jil;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JilSerializer : SerDeser
    {
        // Options is immutable; allocate once (not per serialize call).
        // https://github.com/kevin-montrose/Jil
        private static readonly Options Opts = new Options(
            unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC);

        public override string Name => "Jil";

        public override string Serialize(object serializable)
        {
            using (var sw = new StringWriter())
            {
                JSON.Serialize(serializable, sw, Opts);
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return JSON.Deserialize(sr, _primaryType, Opts);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            JSON.Serialize(serializable, sw, Opts);
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JSON.Deserialize(new StreamReader(inputStream), _primaryType, Opts);
        }
    }
}
