using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class NetJSONSer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "NetJSON"; }
        }

        public override bool Supports(string testDataName)
        {
            // NetJSON does not support circular references in ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            return NetJSON.NetJSON.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return NetJSON.NetJSON.Deserialize(_primaryType, serialized);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            sw.Write(NetJSON.NetJSON.Serialize(serializable));
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return NetJSON.NetJSON.Deserialize(_primaryType, new StreamReader(inputStream).ReadToEnd());
        }

        #endregion
    }
}