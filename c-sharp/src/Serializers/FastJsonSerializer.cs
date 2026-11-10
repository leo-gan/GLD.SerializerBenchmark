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

        public override byte[] SerializeBytes(object serializable)
        {
            return Utf8Bytes(fastJSON.JSON.ToJSON(serializable));
        }

        public override object DeserializeBytes(byte[] serialized)
        {
            return fastJSON.JSON.ToObject(Utf8Text(serialized), _primaryType);
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