///
/// See here https://www.nuget.org/packages/HaveBoxJSONSer/
/// >PM Install-Package HaveBoxJSON
/// 

using System.IO;
using HaveBoxJSON;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class HaveBoxJSONSerializer : SerDeser
    {
        private static readonly JsonConverter _serializer = new JsonConverter();

        #region ISerDeser Members

        public override string Name
        {
            get { return "HaveBoxJSON"; }
        }

        public override string Serialize(object serializable)
        {
            return _serializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return _serializer.Deserialize(_primaryType, serialized);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = _serializer.Serialize(serializable);
            var sw = new StreamWriter(outputStream);
            outputStream.Seek(0, SeekOrigin.Begin);
            sw.Write(str);
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            var sr = new StreamReader(inputStream);
            inputStream.Seek(0, SeekOrigin.Begin);
            var serialized = sr.ReadToEnd();
            return _serializer.Deserialize(_primaryType, serialized);
        }

        #endregion
    }
}