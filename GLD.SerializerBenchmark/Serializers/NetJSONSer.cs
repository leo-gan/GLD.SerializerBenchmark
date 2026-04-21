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
            // NetJSON has issues with direct stream writing; use intermediate string
            var json = NetJSON.NetJSON.Serialize(serializable);
            using (var sw = new StreamWriter(outputStream, leaveOpen: true))
            {
                sw.Write(json);
            }
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using (var sr = new StreamReader(inputStream, leaveOpen: true))
            {
                var json = sr.ReadToEnd();
                return NetJSON.NetJSON.Deserialize(_primaryType, json);
            }
        }

        #endregion
    }
}