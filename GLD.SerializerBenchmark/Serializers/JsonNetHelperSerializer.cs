using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonNetHelperSerializer : ISerDeser
    {
        #region ISerDeser Members

        public string Name {get { return "Json.Net (Helper)"; } }

        public string Serialize<T>(object person)
        {
            return JsonConvert.SerializeObject((T)person);
        }

        public T Deserialize<T>(string serialized)
        {
            return JsonConvert.DeserializeObject<T>(serialized);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            throw new System.NotImplementedException();
        }


        public T Deserialize<T>(Stream inputStream)
        {
            throw new System.NotImplementedException();
        }

        #endregion
    }
}