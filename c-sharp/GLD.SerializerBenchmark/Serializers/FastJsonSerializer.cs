using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class FastJsonSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "fastJson"; }
        }

        public override bool Supports(string testDataName)
        {
            // fastJson does not support circular references in ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            return fastJSON.JSON.ToJSON(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return fastJSON.JSON.ToObject(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            sw.Write(fastJSON.JSON.ToJSON(serializable));
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return fastJSON.JSON.ToObject(new StreamReader(inputStream).ReadToEnd(), _primaryType);
        }

        #endregion
    }
}