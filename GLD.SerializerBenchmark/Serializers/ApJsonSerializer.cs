///
/// See http://www.codeproject.com/Articles/491742/APJSON
/// Manually download a dll from mentioned site and add a reference to it.
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class ApJsonSerializer : ISerDeser
    {
 
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            return Apolyton.FastJson.Json.Current.ToJson(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return Apolyton.FastJson.Json.Current.ReadObject<T>(serialized);
        }

        #endregion
    }
}