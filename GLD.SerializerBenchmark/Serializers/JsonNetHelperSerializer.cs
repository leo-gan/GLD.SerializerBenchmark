using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JsonNetHelperSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "Json.Net (Helper)"; }
        }

        public override string Serialize(object serializable)
        {
            return JsonConvert.SerializeObject(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return JsonConvert.DeserializeObject(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = JsonConvert.SerializeObject(serializable);
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
            return JsonConvert.DeserializeObject(serialized, _primaryType);
        }

        #endregion
    }
}