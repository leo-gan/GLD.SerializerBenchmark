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

        public string Name {get { return "Apolyton.Json"; } }

        public string Serialize<T>(object person)
        {
            return Apolyton.FastJson.Json.Current.ToJson(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return Apolyton.FastJson.Json.Current.ReadObject<T>(serialized);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            throw new NotImplementedException();
        }

 public T Deserialize<T>(Stream inputStream)
        {
            throw new NotImplementedException();
        }

        #endregion
    }
}