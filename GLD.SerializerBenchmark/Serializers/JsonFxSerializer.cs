///
/// https://github.com/jsonfx/jsonfx
/// PM> Install-Package JsonFx
/// by Stephen McKamey
/// 

using System.IO;
using JsonFx.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonFxSerializer : ISerDeser
    {

        static readonly JsonWriter _jw = new JsonWriter();
        static readonly JsonReader _jr = new JsonReader();
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            return _jw.Write(person);
         }

        public T Deserialize<T>(string serialized)
        {
            return _jr.Read<T>(serialized);
        }

        #endregion
    }
}