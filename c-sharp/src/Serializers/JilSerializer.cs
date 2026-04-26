using System;
using System.IO;
using Jil;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JilSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "Jil"; }
        }

        public override bool Supports(string testDataName)
        {
            // Jil does not support circular references in ObjectGraph
            bool isObjectGraph = testDataName == "ObjectGraph";
            // Console.WriteLine($"[DEBUG] Jil.Supports({testDataName}) -> {!isObjectGraph}");
            return !isObjectGraph;
        }

        public override string Serialize(object serializable)
        {
            using (var sw = new StringWriter())
            {
                JSON.Serialize(serializable, sw,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return JSON.Deserialize(sr, _primaryType,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            JSON.Serialize(serializable, sw,
                new Options(
                    unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JSON.Deserialize(new StreamReader(inputStream), _primaryType,
                new Options(
                    unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
        }

        #endregion
    }
}