using Newtonsoft.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonNetSerializer : ISerDeser
    {
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            return JsonConvert.SerializeObject((T)person);
        }

        public T Deserialize<T>(string serialized)
        {
            return JsonConvert.DeserializeObject<T>(serialized);
        }

        #endregion
    }
}