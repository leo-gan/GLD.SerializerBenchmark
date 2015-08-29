using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JsonNetHelperSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name {get { return "Json.Net (Helper)"; } }
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
            throw new System.NotImplementedException();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            throw new System.NotImplementedException();
        }
        #endregion
    }
}