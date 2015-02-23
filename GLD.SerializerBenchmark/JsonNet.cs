using Newtonsoft.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonNet : ISerDeser
    {
        #region ISerDeser Members

        public string Serialize(object person)
        {
            return JsonConvert.SerializeObject(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return JsonConvert.DeserializeObject<T>(serialized);
        }

        #endregion
    }
}