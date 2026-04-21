using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JsonNetHelperSerializer : SerDeser
    {
        private static readonly JsonSerializerSettings _settings = new JsonSerializerSettings
        {
            PreserveReferencesHandling = PreserveReferencesHandling.Objects
        };

        #region ISerDeser Members

        public override string Name
        {
            get { return "Json.Net (Helper)"; }
        }

        public override string Serialize(object serializable)
        {
            return JsonConvert.SerializeObject(serializable, _settings);
        }

        public override object Deserialize(string serialized)
        {
            return JsonConvert.DeserializeObject(serialized, _primaryType, _settings);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = JsonConvert.SerializeObject(serializable, _settings);
            var sw = new StreamWriter(outputStream);
            sw.Write(str);
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            var sr = new StreamReader(inputStream);
            var serialized = sr.ReadToEnd();
            return JsonConvert.DeserializeObject(serialized, _primaryType, _settings);
        }

        #endregion
    }
}