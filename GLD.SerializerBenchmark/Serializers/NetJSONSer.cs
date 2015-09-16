///
/// See here https://github.com/rpgmaker/NetJSON
/// >PM Install-Package NetJSON
/// 

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
            NetJSON.NetJSON.Serialize(serializable, sw);
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            var sr = new StreamReader(inputStream);
            return NetJSON.NetJSON.Deserialize(_primaryType, sr.ReadToEnd());
        }

        #endregion
    }
}