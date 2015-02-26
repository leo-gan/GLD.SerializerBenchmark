///
/// https://github.com/jsonfx/jsonfx
/// PM> Install-Package JsonFx
/// TODO: DateTime fields is still under work.

using System.IO;
using JsonFx.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonFxSerializer : ISerDeser
    {

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            var jw = new JsonWriter();
            return jw.Write(person);
         }

        public T Deserialize<T>(string serialized)
        {
            var jr = new JsonReader();
            return jr.Read<T>(serialized);
        }

        #endregion
    }
}