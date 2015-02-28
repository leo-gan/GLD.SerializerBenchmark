///
/// See https://github.com/alibaba/fastjson
/// >PM Install-Package fastJSON
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    internal class FastJsonSerializer : ISerDeser
    {
 
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
               return fastJSON.JSON.ToJSON(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return fastJSON.JSON.ToObject<T>(serialized);
        }

        #endregion
    }
}